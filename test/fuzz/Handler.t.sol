// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralisedStableCoin } from "../../src/DecentralisedStableCoin.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";


contract Handler is Test {
    
    DSCEngine dscEngine;
    DecentralisedStableCoin dsc;
    MockV3Aggregator ethUsdPriceFeed;
    MockV3Aggregator btcUsdPriceFeed;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public constant MAX_DEPOSIT_SIZE = type(uint96).max;
    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;

    constructor(DSCEngine _dscEngine, DecentralisedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        // Get eth usd price feed
        ethUsdPriceFeed = MockV3Aggregator(dscEngine.getPriceFeedForToken(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(dscEngine.getPriceFeedForToken(address(wbtc)));
    }

    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    function mintDsc(uint256 dscAmount, uint256 addressSeed ) public {
        timesMintIsCalled++;
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        dscAmount = bound(dscAmount, 1, MAX_DEPOSIT_SIZE);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(sender);
        int256 maxDSCToMint = int(collateralValueInUsd) / 2 - int(totalDscMinted); // Because of the collateral ratio
        if (maxDSCToMint < 0) {
            return;
        }
        dscAmount = bound(dscAmount, 0, uint256(maxDSCToMint));
        if (dscAmount == 0) {
            return;
        } 
        vm.startPrank(sender);
        dscEngine.mintDsc(dscAmount);
        vm.stopPrank();
    }

    function depositCollateral(uint256 collateralSeed, uint256 collateralAmount) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        collateralAmount = bound(collateralAmount, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, collateralAmount);
        collateral.approve(address(this), collateralAmount);
        dscEngine.depositCollateral(address(collateral), collateralAmount);
        usersWithCollateralDeposited.push(msg.sender);
        vm.stopPrank();
    }

    function redeemCollateral(uint256 collateralSeed, uint256 collateralAmount) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dscEngine.getCollateralBalanceOfTheUser(msg.sender, address(collateral));
        collateralAmount = bound(collateralAmount, 0, maxCollateralToRedeem);
        if (collateralAmount == 0) {
            return;
        }
        vm.prank(msg.sender);
        dscEngine.redeemCollateral(address(collateral), collateralAmount);
    }

    // Helper functions
    function _getCollateralFromSeed(uint256 collateralSeed) public view returns (ERC20Mock) {
        if (collateralSeed%2 == 0) {
            return weth;
        }
        return wbtc;
    }
}