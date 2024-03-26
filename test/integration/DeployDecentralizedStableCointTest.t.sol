// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DeployDecentralizedStableCoinTest is Test {
    DeployDecentralizedStableCoin private deployDecentralizedStableCoin;
    DecentralizedStableCoin private decentralizedStableCoin;

    function setUp() public {
        deployDecentralizedStableCoin = new DeployDecentralizedStableCoin();
        decentralizedStableCoin = deployDecentralizedStableCoin.run();
    }

    function testUserCanMint() public {
        vm.prank(decentralizedStableCoin.owner());
        decentralizedStableCoin.mint(address(this), 10);
        assert(decentralizedStableCoin.balanceOf(address(this)) == 10);
    }
}
