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
// interfaces, libraries, contracts
// errors
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
// view & pure functions

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

    /////////////////
    /// State Var //////
    ////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_userCollateral;
    mapping(address user => uint256 amountDsc) private s_userDsc;
    address[] private s_collaterTokens;
    DecentralizedStableCoin private immutable i_dsc;

    ////////////////
    /// Events ////
    ///////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

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
    function depositCollateralAndMintDsc(uint256 _amount) external {
        // Deposit collateral
        // Mint DSC
    }

    /**
     * @param _tokenCollateralAddress Address of the token to deposit as collateral
     * @param _amount Amount of the token to deposit as collateral
     */
    function depositCollateral(address _tokenCollateralAddress, uint256 _amount)
        external
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

    function redeemCollateralForDsc(uint256 _amount) external {
        // Redeem DSC
        // Withdraw collateral
    }

    function redeemCollateral(uint256 _amount) external {
        // Withdraw collateral
    }

    /**
     * @notice follows CEI
     * @param _amount Amount of DSC to mint
     */
    function mintDsc(uint256 _amount) external moreThanZero(_amount) nonReentrant {
        s_userDsc[msg.sender] += _amount;
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(uint256 _amount) external {
        // Burn DSC
    }

    function liquidateDsc(uint256 _amount) external {
        // Liquidate DSC
    }

    function getHealthFactor() external view returns (uint256) {
        // Get health factor
    }

    ////////////////
    /// Pub Functions //
    ///////////////
    function getAccountCollateralInUsd(address _user) public view returns (uint256 totalCollateralInUsd) {
        for (uint256 i = 0; i < s_collaterTokens.length; i++) {
            address token = s_collaterTokens[i];
            uint256 userCollateralAmount = s_userCollateral[_user][token];
            totalCollateralInUsd += _getUsdValue(token, userCollateralAmount);
        }

        return totalCollateralInUsd;
    }

    ////////////////
    /// Internal Func //
    ///////////////

    ////////////////
    /// Private Functions //
    ///////////////
    function _getUsdValue(address _token, uint256 _amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) / PRECISION;
    }

    function _revertIfHealthFactorIsBroken(address _user) private view {
        // Revert if health factor is broken
    }

    function _getHealthFactor(address _user) private view returns (uint256) {
        // Get health factor
    }

    function _getAccountInformation(address _user) private view returns (uint256, uint256) {
        uint256 totalDscMinted = s_userDsc[_user];
        uint256 totalCollateralInUsd = getAccountCollateralInUsd(_user);
    }
}
