// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    address[] usersDeposited;
    int256 public maxDSC;
    uint256 constant MAX_UINT96 = type(uint96).max;
    MockV3Aggregator ethUsdPriceFeed;

    constructor(DSCEngine _dsce, DecentralizedStableCoin _dsc) {
        dsc = _dsc;
        dsce = _dsce;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getPriceFeed(address(weth)));
    }

    // deposit collateral
    function depositCollateral(uint256 _collateralSeed, uint256 _amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(_collateralSeed);
        _amountCollateral = bound(_amountCollateral, 1, MAX_UINT96);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, _amountCollateral);
        collateral.approve(address(dsce), _amountCollateral);
        dsce.depositCollateral(address(collateral), _amountCollateral);
        usersDeposited.push(msg.sender);
        vm.stopPrank();
    }

    // redeem collateral
    function redeemCollateral(uint256 _collateralSeed, uint256 _amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(_collateralSeed);
        uint256 maxCollateral = dsce.getUserCollateral(msg.sender, address(collateral));
        _amountCollateral = bound(_amountCollateral, 0, maxCollateral);
        if (_amountCollateral == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        dsce.redeemCollateral(address(collateral), _amountCollateral);
        vm.stopPrank();
    }

    // mint DSC
    function mintDSC(uint256 _amountDSC, uint256 _addressSeed) public {
        if (usersDeposited.length == 0) {
            return;
        }
        address sender = usersDeposited[_addressSeed % usersDeposited.length];
        (uint256 totalDscMinted, uint256 totalCollateralValue) = dsce.getAccountInformation(sender);
        int256 maxDscToMint = (int256(totalCollateralValue) / 2) - int256(totalDscMinted);
        if (maxDscToMint < 0) {
            return;
        }
        _amountDSC = bound(_amountDSC, 0, uint256(maxDscToMint));
        if (_amountDSC == 0) {
            return;
        }

        vm.startPrank(sender);
        dsce.mintDsc(_amountDSC);
        vm.stopPrank();
    }

    // function updateCollateralPrice(uint96 _newPrice) public { TODO try to fix this
    //     int256 newPriceInt = int256(uint256(_newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    //Helper function to get the value of the collateral
    function _getCollateralFromSeed(uint256 _collateralSeed) private view returns (ERC20Mock) {
        if (_collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
