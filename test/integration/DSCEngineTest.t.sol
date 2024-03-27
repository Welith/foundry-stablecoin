// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSCEngine private deployDSCEngine;
    DSCEngine private engine;
    DecentralizedStableCoin private dsc;
    HelperConfig private helperConfig;

    address wethUsdPriceFeed;
    address weth;
    address private _USER = makeAddr("USER");

    function setUp() public {
        deployDSCEngine = new DeployDSCEngine();
        (dsc, engine, helperConfig) = deployDSCEngine.run();

        (wethUsdPriceFeed,, weth,,) = helperConfig.activeConfig();

        ERC20Mock(weth).mint(_USER, 100 ether);
    }

    //////////////////
    /// Price Feed ///
    //////////////////
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedEthUsdValue = 30000e18;
        uint256 actualEthUsdValue = engine.getUsdValue(weth, ethAmount);
        assertEq(actualEthUsdValue, expectedEthUsdValue);
    }

    function testRevertsIfCollateralIsZero() public {
        vm.startPrank(_USER);
        ERC20Mock(weth).approve(address(engine), 10 ether);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
