// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { DeployDSC } from "../../script/DeployDSC.s.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralisedStableCoin } from "../../src/DecentralisedStableCoin.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Handler } from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    
    DeployDSC deployer;
    DSCEngine dscEngine;
    DecentralisedStableCoin dsc;
    HelperConfig helperConfig;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        // Mention here the target contract for the invariant
        (, , weth, wbtc,) = helperConfig.activeNetworkConfig();
        handler = new Handler(dscEngine, dsc);
        targetContract(address(handler));
    }

    function invariant_testProtocolMustHaveMoreCollateralValueThanDscMinted() public view {
        uint256 totalDscMinted = dsc.totalSupply();
        // Calculate the collateral value
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsc));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsc));

        uint256 wethValue = dscEngine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dscEngine.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("totalDscMinted: ", totalDscMinted);
        console.log("wethValue: ", wethValue);
        console.log("wbtcValue: ", wbtcValue);
        console.log("times mint is called: ", handler.timesMintIsCalled());

        assert(totalDscMinted <= wethValue + wbtcValue);
    } 

    function invariant_getterShouldNotReturn() public view {
        dscEngine.getPriceFeedForToken(weth);
        dscEngine.getPriceFeedForToken(wbtc);
        dscEngine.getCollateralTokens();
        dscEngine.getUsdValue(weth, 1);
        dscEngine.getUsdValue(wbtc, 1);
    }
    
}