// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author Boris Kolev
 * @notice This library is used to interact with ChainLink oracles to check if price is stale.
 * @notice If the pricefeed is stale, the oracle will freeze the protocol.
 */
library OracleLib {
    error OracleLin__StalePriceFeed();

    uint256 private constant TIMEOUT = 3 hours;

    function stalePriceCheck(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSinceLastUpdate = block.timestamp - updatedAt;
        if(secondsSinceLastUpdate > TIMEOUT) {
            revert OracleLin__StalePriceFeed();
        }

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
