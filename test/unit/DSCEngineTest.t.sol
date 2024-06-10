// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { DeployDSC } from "../../script/DeployDSC.s.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralisedStableCoin } from "../../src/DecentralisedStableCoin.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";


contract DSCEngineTest is Test {

    DeployDSC deployer;
    DecentralisedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 100 ether;

    function setUp() public {
        // Deploy the contract
        deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed,, weth,,) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    //////////////////////////////
    // Price Tests 
    //////////////////////////////

    function testGetUsdValue() external view {
        uint256 amount = 100; // 100 WETH
        // int256 ethPriceinUsd = helperConfig.ETH_USD_PRICE();
        uint256 expectedPrice = amount * 2000;
        uint256 calculatedPrice = dscEngine.getUsdValue(weth, amount);
        assertEq(calculatedPrice, expectedPrice);
    }

    //////////////////////////////
    // Deposit Collateral Tests 
    //////////////////////////////

    function testRevertsIfCollateralZero() external {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        uint256 collateralAmount = 0;
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, collateralAmount);
        vm.stopPrank();
    }

    function testDepositCollateral() external {
        
    }
}