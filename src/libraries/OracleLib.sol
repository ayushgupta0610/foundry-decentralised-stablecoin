// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
    * @title OracleLib
    * @author Ayush Gupta
    * @notice This library is used to check the Chainlink oracle for price data
    * We want the DSCEngine to freeze if prices become stale
*/
library OracleLib {
    error OracleLib__StalePriceData();

    uint256 public constant MAX_TIMEOUT = 3 hours; // Chainlink oracles are updated every hour

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed) public view returns (
      uint80 latestRoundId,
      int256 latestAnswer,
      uint256 latestStartedAt,
      uint256 latestUpdatedAt,
      uint80 latestAnsweredInRound
    ) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        if (block.timestamp - updatedAt > MAX_TIMEOUT) {
            revert OracleLib__StalePriceData();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}