//SPDX-License-Identifier: MIT
// The total amount of DSC needs to always be less than the total value of collateral.abi
// Getters should never revert
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    DeployDSCEngine engineDeployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig helperConfig;
    Handler handler;

    address weth;
    address wbtc;

    function setUp() public {
        engineDeployer = new DeployDSCEngine();
        (dsc, dsce, helperConfig) = engineDeployer.run();
        (,, weth, wbtc,) = helperConfig.activeConfig();
        handler = new Handler(dsce, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("wethValue: ", wethValue);
        console.log("wethValue: ", wethValue);
        console.log("totalSupply: ", totalSupply);

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNotRevert() public view {
        dsce.getFeedPrecision();
        dsce.getLiquidationBonus();
        dsce.getLiquidationPrecision();
        dsce.getPrecision();
        dsce.getMinHealthFactor();
    }
}
