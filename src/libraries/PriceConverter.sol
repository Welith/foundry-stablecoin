// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    function getConversionData(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function getMinUsd(uint256 fundedEth, AggregatorV3Interface priceFeed) internal view returns (uint256) {
        return ((fundedEth * (getConversionData(priceFeed) * 10 ** 8))) / 10 ** 18;
    }
}
