// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

/**
 * @title DecentralizedStableCoin
 * @author Boris Kolev (0xb0k0)
 * @notice Governed by DSCEngine. ERC20 compatible representation of a Stable Coin.
 * @notice Collateral: Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized
 * @notice Minting: Algorithmic
 * @notice Relative Stability: Pegged to USD
 */
contract MockBrokenDSC is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__MintAddressCantBeZeroAddress();

    address private mockV3Aggregator;

    constructor(address _mockV3Aggregator) ERC20("Decentralized Stable Coin", "DSC") {
        mockV3Aggregator = _mockV3Aggregator;
    }

    function burn(uint256 _amount) public override onlyOwner {
        MockV3Aggregator(mockV3Aggregator).updateAnswer(0); // We break the system
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        if (_amount > balance) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__MintAddressCantBeZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
