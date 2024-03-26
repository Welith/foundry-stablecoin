// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin private decentralizedStableCoin;

    function setUp() public {
        decentralizedStableCoin = new DecentralizedStableCoin();
    }

    function testBurnWithZeroAmountShouldRevert() public {
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__MustBeMoreThanZero
                .selector
        );
        decentralizedStableCoin.burn(0);
    }

    function testBurnWithAmountBiggerThanBalanceShouldRevert() public {
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__BurnAmountExceedsBalance
                .selector
        );
        decentralizedStableCoin.burn(10);
    }

    function testMintWithZeroAddressShouldRevert() public {
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__MintAddressCantBeZeroAddress
                .selector
        );
        decentralizedStableCoin.mint(address(0), 10);
    }

    function testMintWithZeroAmountShouldRevert() public {
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__MustBeMoreThanZero
                .selector
        );
        decentralizedStableCoin.mint(address(this), 0);
    }

    function testMintShouldIncreaseUserBalance() public {
        decentralizedStableCoin.mint(address(this), 10);
        assert(decentralizedStableCoin.balanceOf(address(this)) == 10);
    }

    function testBurnWithNotOwnerShouldRevert() public {
        decentralizedStableCoin.mint(address(this), 10);
        vm.prank(makeAddr("notOwner"));
        vm.expectRevert("Ownable: caller is not the owner");
        decentralizedStableCoin.burn(10);
    }

    function testBurnShouldReduceUserBalance() public {
        vm.startPrank(decentralizedStableCoin.owner());
        decentralizedStableCoin.mint(address(this), 10);
        decentralizedStableCoin.burn(5);
        assert(decentralizedStableCoin.balanceOf(address(this)) == 5);
        vm.stopPrank();
    }

    function testCannotBurnMoreThanBalance() public {
        vm.startPrank(decentralizedStableCoin.owner());
        decentralizedStableCoin.mint(address(this), 10);
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__BurnAmountExceedsBalance
                .selector
        );
        decentralizedStableCoin.burn(15);
        vm.stopPrank();
    }
}
