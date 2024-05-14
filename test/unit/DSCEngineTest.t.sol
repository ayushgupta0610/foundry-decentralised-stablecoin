// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { DeployDSC } from "../../script/DeployDSC.s.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralisedStableCoin } from "../../src/DecentralisedStableCoin.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";


contract DSCEngineTest is Test {

    DeployDSC deployer;
    DecentralisedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address weth;

    function setUp() public {
        // Deploy the contract
        deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = helperConfig.activeNetworkConfig();
    }

    function testGetUsdValue() external {
        uint256 amount = 100; // 100 WETH
        // int256 ethPriceinUsd = helperConfig.ETH_USD_PRICE();
        uint256 expectedPrice = amount * 2000;
        uint256 calculatedPrice = dscEngine.getUsdValue(weth, amount);
        assertEq(calculatedPrice, expectedPrice);
    }
}