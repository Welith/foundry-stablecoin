// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockFailedDSCMint} from "../mocks/MockFailedDSCMint.sol";
import {MockFailedDSCTransferFrom} from "../mocks/MockFailedDSCTransferFrom.sol";
import {MockFailedDSCTransfer} from "../mocks/MockFailedDSCTransfer.sol";
import {MockBrokenDSC} from "../mocks/MockBrokenDSC.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSCEngine private deployDSCEngine;
    DSCEngine private engine;
    DecentralizedStableCoin private dsc;
    HelperConfig private helperConfig;

    address wethUsdPriceFeed;
    address weth;
    address private _USER = makeAddr("USER");
    address[] tokenAddresses;
    address[] priceFeedAddresses;

    uint256 private constant DEPOSITED_COLLATERAL = 10 ether;
    uint256 private constant INITIAL_USER_WETH_BALANCE = 100 ether;
    uint256 private constant MINTED_DSC = 100 ether;
    uint256 private constant BAD_MINTED_DSC = 100 ether;

    modifier depositCollateral() {
        vm.startPrank(_USER);
        ERC20Mock(weth).approve(address(engine), DEPOSITED_COLLATERAL);
        engine.depositCollateral(weth, DEPOSITED_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployDSCEngine = new DeployDSCEngine();
        (dsc, engine, helperConfig) = deployDSCEngine.run();

        (wethUsdPriceFeed,, weth,,) = helperConfig.activeConfig();

        ERC20Mock(weth).mint(_USER, INITIAL_USER_WETH_BALANCE);
    }

    //////////////////
    /// Constructor ///
    //////////////////
    function testProtocolRevertsIfTokenAddressesAndPriceFeedAddressesDiffer() public {
        tokenAddresses = new address[](1);
        priceFeedAddresses = new address[](2);
        vm.expectRevert(DSCEngine.DSCEngine__TokensDoNotMatchPriceFeedLength.selector);
        engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////
    /// Price Feed ///
    //////////////////
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedEthUsdValue = 30000e18;
        uint256 actualEthUsdValue = engine.getUsdValue(weth, ethAmount);
        assertEq(actualEthUsdValue, expectedEthUsdValue);
    }

    function testGetTokenAmoutFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedEthAmount = 0.05 ether;
        uint256 actualEthAmount = engine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualEthAmount, expectedEthAmount);
    }

    //////////////////
    /// Collateral ///
    //////////////////
    function testRevertsIfCollateralIsZero() public {
        vm.startPrank(_USER);
        ERC20Mock(weth).approve(address(engine), DEPOSITED_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock newToken = new ERC20Mock("TEST", "TEST", address(this), 100 ether);

        vm.startPrank(_USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotSupported.selector);
        engine.depositCollateral(address(newToken), DEPOSITED_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 debt, uint256 collateral) = engine.getAccountInformation(_USER);
        uint256 expectedCollateral = engine.getUsdValue(weth, DEPOSITED_COLLATERAL);
        assertEq(collateral, expectedCollateral);
        assertEq(debt, 0);
    }

    function testRevertsIfTransferFromFails() public {
        MockFailedDSCTransferFrom failedDsc = new MockFailedDSCTransferFrom();
        tokenAddresses = [address(failedDsc)];
        priceFeedAddresses = [wethUsdPriceFeed];
        DSCEngine engineWithFailedDsc = new DSCEngine(tokenAddresses, priceFeedAddresses, address(failedDsc));
        failedDsc.transferOwnership(address(engineWithFailedDsc));

        ERC20Mock(address(failedDsc)).approve(address(engineWithFailedDsc), DEPOSITED_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        engineWithFailedDsc.depositCollateral(address(failedDsc), DEPOSITED_COLLATERAL);
    }

    //////////////////
    /// Mint ///
    //////////////////
    function testMintRevertsIfZeroAmount() public {
        vm.startPrank(_USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.mintDsc(0);
        vm.stopPrank();
    }

    function testMintAddsDscToUser() public depositCollateral {
        vm.startPrank(_USER);
        engine.mintDsc(MINTED_DSC);
        vm.stopPrank();

        uint256 dscBalance = dsc.balanceOf(_USER);
        assertEq(dscBalance, MINTED_DSC);
    }

    function testMintRevertsIfUserHealthFactorIsBelowThreshold() public depositCollateral {
        vm.startPrank(_USER);
        uint256 expectedCollateralInUsd = engine.getUsdValue(weth, DEPOSITED_COLLATERAL);
        uint256 expectedHealthFactor = engine.calculateHealthFactor(expectedCollateralInUsd, 1000000 ether);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.mintDsc(1000000 ether);
        vm.stopPrank();
    }

    function testMintRevertIfMintFails() public {
        MockFailedDSCMint failedDsc = new MockFailedDSCMint();
        tokenAddresses = [weth];
        priceFeedAddresses = [wethUsdPriceFeed];
        DSCEngine engineWithFailedDsc = new DSCEngine(tokenAddresses, priceFeedAddresses, address(failedDsc));
        failedDsc.transferOwnership(address(engineWithFailedDsc));

        vm.startPrank(_USER);
        ERC20Mock(weth).approve(address(engineWithFailedDsc), DEPOSITED_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        engineWithFailedDsc.depositCollateralAndMintDsc(weth, DEPOSITED_COLLATERAL, MINTED_DSC);
        vm.stopPrank();
    }

    ////////////////////
    /// Redeem ////////
    //////////////////
    function testRedeemRevertsIfZeroAmount() public {
        vm.startPrank(_USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRedeemRemovesCollateralFromUserAndSendsToUser() public depositCollateral {
        assertEq(ERC20Mock(weth).balanceOf(_USER), INITIAL_USER_WETH_BALANCE - DEPOSITED_COLLATERAL);
        vm.startPrank(_USER);
        engine.redeemCollateral(weth, DEPOSITED_COLLATERAL);
        vm.stopPrank();

        (uint256 debt, uint256 collateral) = engine.getAccountInformation(_USER);
        assertEq(debt, 0);
        assertEq(collateral, 0);
        assertEq(ERC20Mock(weth).balanceOf(_USER), INITIAL_USER_WETH_BALANCE);
    }

    function testRedeemRevertsIfHealthFactorIsBelowThreshold() public depositCollateral {
        vm.startPrank(_USER);
        engine.mintDsc(MINTED_DSC);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));
        engine.redeemCollateral(weth, DEPOSITED_COLLATERAL);
        vm.stopPrank();
    }

    function testRedeemRevertsIfTransferFails() public {
        MockFailedDSCTransfer failedDsc = new MockFailedDSCTransfer();
        tokenAddresses = [address(failedDsc)];
        priceFeedAddresses = [wethUsdPriceFeed];
        DSCEngine engineWithFailedDsc = new DSCEngine(tokenAddresses, priceFeedAddresses, address(failedDsc));
        failedDsc.mint(_USER, DEPOSITED_COLLATERAL);

        failedDsc.transferOwnership(address(engineWithFailedDsc));

        vm.startPrank(_USER);
        ERC20Mock(address(failedDsc)).approve(address(engineWithFailedDsc), DEPOSITED_COLLATERAL);
        engineWithFailedDsc.depositCollateral(address(failedDsc), DEPOSITED_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        engineWithFailedDsc.redeemCollateral(address(failedDsc), DEPOSITED_COLLATERAL);
        vm.stopPrank();
    }

    ////////////////////
    /// Burn ////////
    //////////////////
    function testBurnRevertsIfZeroAmount() public {
        vm.startPrank(_USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.burnDsc(0);
        vm.stopPrank();
    }

    function testBurnRemovesDscFromUser() public depositCollateral {
        vm.startPrank(_USER);
        dsc.approve(address(engine), MINTED_DSC);
        engine.mintDsc(MINTED_DSC);
        engine.burnDsc(MINTED_DSC);
        vm.stopPrank();

        uint256 dscBalance = dsc.balanceOf(_USER);
        assertEq(dscBalance, 0);
    }

    ////////////////////
    /// Liquidate ////////
    //////////////////

    function testLiquidateMustImproveHealthFactor() public {
        MockBrokenDSC failedDsc = new MockBrokenDSC(wethUsdPriceFeed);
        tokenAddresses = [weth];
        priceFeedAddresses = [wethUsdPriceFeed];
        vm.prank(msg.sender);
        DSCEngine engineWithFailedDsc = new DSCEngine(tokenAddresses, priceFeedAddresses, address(failedDsc));
        failedDsc.transferOwnership(address(engineWithFailedDsc));

        vm.startPrank(_USER);
        ERC20Mock(weth).approve(address(engineWithFailedDsc), DEPOSITED_COLLATERAL);
        engineWithFailedDsc.depositCollateralAndMintDsc(weth, DEPOSITED_COLLATERAL, MINTED_DSC);
        vm.stopPrank();

        address liquidator = makeAddr("LIQUIDATOR");
        ERC20Mock(weth).mint(liquidator, 1 ether);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engineWithFailedDsc), 1 ether);
        engineWithFailedDsc.depositCollateralAndMintDsc(weth, 1 ether, 10 ether);
        failedDsc.approve(address(engineWithFailedDsc), 10 ether);
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(18e8);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorNotImproved.selector);
        engineWithFailedDsc.liquidate(weth, _USER, 10 ether);
        vm.stopPrank();
    }

    function testLiquidateRevertsIfDebtIsZero() public {
        vm.startPrank(_USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        engine.liquidate(weth, _USER, 0);
        vm.stopPrank();
    }

    function testLiquidateRevertsIfHealthFactorIsAboveThreshold() public depositCollateral {
        vm.startPrank(_USER);
        engine.mintDsc(MINTED_DSC);
        uint256 expectedCollateralInUsd = engine.getUsdValue(weth, DEPOSITED_COLLATERAL);
        uint256 expectedHealthFactor = engine.calculateHealthFactor(expectedCollateralInUsd, MINTED_DSC);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__HealthFactorIsOK.selector, expectedHealthFactor));
        engine.liquidate(weth, _USER, MINTED_DSC);
        vm.stopPrank();
    }

    modifier liquidate() {
        vm.startPrank(_USER);
        ERC20Mock(weth).approve(address(engine), DEPOSITED_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, DEPOSITED_COLLATERAL, MINTED_DSC);
        vm.stopPrank();
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(18e8);

        address liquidator = makeAddr("LIQUIDATOR");
        ERC20Mock(weth).mint(liquidator, 20 ether);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engine), 20 ether);
        engine.depositCollateralAndMintDsc(weth, 20 ether, 100 ether);
        dsc.approve(address(engine), 100 ether);
        engine.liquidate(weth, _USER, 100 ether);
        vm.stopPrank();
        _;
    }

    function testLiquidateLeavesSomeEtherOnUser() public liquidate {
        (, uint256 collateral) = engine.getAccountInformation(_USER);
        assertEq(collateral, 70000000000000000020);
    }
}
