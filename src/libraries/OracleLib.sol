// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    uint256 private constant TIME_OUT = 3 hours;
    error OracleLib__StalePrice();

    function staleCheckLatestRoundData(
        AggregatorV3Interface priceFeeds
    ) public view returns (uint80, int256, uint256, uint256, uint80) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeeds.latestRoundData();
        uint256 dateFeedsResponse = block.timestamp - updatedAt;
        if (dateFeedsResponse > TIME_OUT) {
            revert OracleLib__StalePrice();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
