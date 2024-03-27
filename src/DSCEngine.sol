// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

/**
 * @title DSCEngine
 * @author Boris Kolev (0xb0k0)
 * @notice This contract is the core of the DSC system. Handles minting and burning of the DSC token.
 *
 * The system is designed to be as minimal as possible, with the goal of being a decentralized stable coin. The peg is 1 DSC : 1 $.
 * Similar to DAI, if DAI did not have any fees, no governance, and was not backed only by wETH and wBTC.
 * Our DSC system should be always overcollateralized, and the collateral should be diversified.
 */
contract DSCEngine is ReentrancyGuard {
    /////////////////
    /// ERRORS //////
    ////////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokensDoNotMatchPriceFeedLength();
    error DSCEngine__TokenNotSupported();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorIsOK(uint256 healthFactor);
    error DSCEngine__HealthFactorNotImproved();

    /////////////////
    /// State Var //////
    ////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_userCollateral;
    mapping(address user => uint256 amountDsc) private s_userDsc;
    address[] private s_collaterTokens;

    DecentralizedStableCoin private immutable i_dsc;

    ////////////////
    /// Events ////
    ///////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(address indexed redeemFrom, address redeemedTo, address indexed token, uint256 amount);
    event DscBurned(address indexed user, uint256 amount);

    ////////////
    /// MODIFIERS //
    ///////////////
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert DSCEngine__TokenNotSupported();
        }
        _;
    }

    ////////////////
    /// Functions //
    ///////////////
    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddress, address _dscAddress) {
        if (_tokenAddresses.length != _priceFeedAddress.length) {
            revert DSCEngine__TokensDoNotMatchPriceFeedLength();
        }

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_priceFeeds[_tokenAddresses[i]] = _priceFeedAddress[i];
            s_collaterTokens.push(_tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(_dscAddress);
    }

    ////////////////
    /// Ext Functions //
    ///////////////

    /**
     *
     * @param _tokenCollateralAddress collateral token address
     * @param _collateralAmount amount of collateral to deposit
     * @param _amountDsc amount of DSC to mint
     * @notice this function will deposit collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(address _tokenCollateralAddress, uint256 _collateralAmount, uint256 _amountDsc)
        external
    {
        depositCollateral(_tokenCollateralAddress, _collateralAmount);
        mintDsc(_amountDsc);
    }

    /**
     *
     * @param _tokenColletaralAddress The collateral token address
     * @param _amountCollateral The amount of collateral to redeem
     * @param _dscAmountToBurn The amount of DSC to burn
     * @notice This function will redeem collateral and burn DSC in one transaction
     */
    function redeemCollateralForDsc(
        address _tokenColletaralAddress,
        uint256 _amountCollateral,
        uint256 _dscAmountToBurn
    ) external {
        _burnDsc(_dscAmountToBurn, msg.sender, msg.sender);
        _redeemCollateral(_tokenColletaralAddress, _amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     *
     * @param _collateral The collateral token address to liquidate
     * @param _user The user to liquidate
     * @param _debtAmount The amount of debt to liquidate
     * @notice This function will liquidate the debt of a user if their health factor is below the threshold.
     * @notice You can partially liquidate the debt of a user.
     * @notice You will get a bonus if you liquidate the debt.
     * @notice This function working assuemes that the overcollateralization is 2x.
     * @notice A known bug would be if the protocol is 100% collateralized, the liquidator will not get any bonus.
     */
    function liquidate(address _collateral, address _user, uint256 _debtAmount)
        external
        moreThanZero(_debtAmount)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(_user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsOK(startingUserHealthFactor);
        }
        _burnDsc(_debtAmount, msg.sender, _user);
        uint256 collateralToRedeem = getTokenAmountFromUsd(_collateral, _debtAmount);
        uint256 bonus = (collateralToRedeem * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = collateralToRedeem + bonus;
        _redeemCollateral(_collateral, totalCollateralToRedeem, _user, msg.sender);
        _burnDsc(_debtAmount, _user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(_user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    ////////////////
    /// Pub Functions //
    ///////////////
    function burnDsc(uint256 _amount) public moreThanZero(_amount) nonReentrant {
        _burnDsc(_amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateral(address _tokenCollateralAddress, uint256 _amountCollateral)
        public
        moreThanZero(_amountCollateral)
        nonReentrant
    {
        _redeemCollateral(_tokenCollateralAddress, _amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice follows CEI
     * @param _amount Amount of DSC to mint
     */
    function mintDsc(uint256 _amount) public moreThanZero(_amount) nonReentrant {
        s_userDsc[msg.sender] += _amount;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, _amount);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    /**
     * @param _tokenCollateralAddress Address of the token to deposit as collateral
     * @param _amount Amount of the token to deposit as collateral
     */
    function depositCollateral(address _tokenCollateralAddress, uint256 _amount)
        public
        moreThanZero(_amount)
        isAllowedToken(_tokenCollateralAddress)
        nonReentrant
    {
        s_userCollateral[msg.sender][_tokenCollateralAddress] += _amount;
        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _amount);
        // Deposit collateral
        bool success = IERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    ////////////////
    /// Internal Func //
    ///////////////

    ////////////////
    /// Private Functions //
    ///////////////
    function _redeemCollateral(address _tokenCollateralAddress, uint256 _amountCollateral, address _from, address _to)
        private
    {
        s_userCollateral[_from][_tokenCollateralAddress] -= _amountCollateral;
        emit CollateralRedeemed(_from, _to, _tokenCollateralAddress, _amountCollateral);
        bool success = IERC20(_tokenCollateralAddress).transfer(_to, _amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @dev Only to be called by a function that checks if the health factor is broken
     */
    function _burnDsc(uint256 _amount, address _onBehalfOf, address dscFrom) private {
        s_userDsc[_onBehalfOf] -= _amount;
        bool success = i_dsc.transferFrom(dscFrom, address(this), _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(_amount);
        emit DscBurned(dscFrom, _amount);
    }

    ////////////////
    /// Internal & Private View & Pure Functions //
    ///////////////
    function _getAccountInformation(address _user) private view returns (uint256, uint256) {
        uint256 totalDscMinted = s_userDsc[_user];
        uint256 totalCollateralInUsd = getAccountCollateralInUsd(_user);

        return (totalDscMinted, totalCollateralInUsd);
    }

    function _healthFactor(address _user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 totalCollateralInUsd) = _getAccountInformation(_user);
        if (totalDscMinted == 0) return type(uint256).max; // Otherwise we would divide by zero
        uint256 collateralAdjustedForThreshold = (totalCollateralInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address _user) private view {
        uint256 userHealthFactor = _healthFactor(_user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _getUsdValue(address _token, uint256 _amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) / PRECISION;
    }

    ////////////////
    /// External & Public View & Pure Functions //
    /////////////
    function getTokenAmountFromUsd(address _token, uint256 _usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (_usdAmountInWei * PRECISION) / uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getAccountInformation(address _user) external view returns (uint256, uint256) {
        return _getAccountInformation(_user);
    }

    function getUsdValue(
        address token,
        uint256 amount // in WEI
    ) external view returns (uint256) {
        return _getUsdValue(token, amount);
    }

    function getAccountCollateralInUsd(address _user) public view returns (uint256 totalCollateralInUsd) {
        for (uint256 i = 0; i < s_collaterTokens.length; i++) {
            address token = s_collaterTokens[i];
            uint256 userCollateralAmount = s_userCollateral[_user][token];
            totalCollateralInUsd += _getUsdValue(token, userCollateralAmount);
        }

        return totalCollateralInUsd;
    }

    function getHealthFactor(address _user) public view returns (uint256) {
        return _healthFactor(_user);
    }
}
