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
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 100 ether;

    function setUp() public {
        // Deploy the contract
        deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    //////////////////////////////
    // Constructor Tests 
    //////////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() external {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    //////////////////////////////
    // Price Tests 
    //////////////////////////////

    function testGetTokenAmountFromUsd() external view {
        uint256 usdAmount = 1000 ether;
        uint256 expectedWeth = 0.5 ether;
        uint256 actualWeth = dscEngine.getTokenAmountFromUsdValue(weth, usdAmount);
        assert(actualWeth == expectedWeth);
    }

    function testGetUsdValueFromTokenAmount() external view {
        uint256 wethAmount = .5 ether;
        uint256 expectedUsdValue = 1000 ether;
        uint256 actualUsdValue = dscEngine.getUsdValue(weth, wethAmount);
        assert(actualUsdValue == expectedUsdValue);
    }

    // This should ideally be network dependant
    function testGetUsdValue() external view {
        uint256 amount = 100; // 100 WETH
        // int256 ethPriceinUsd = helperConfig.ETH_USD_PRICE();
        uint256 expectedPrice = amount * 2000;
        uint256 calculatedPrice = dscEngine.getUsdValue(weth, amount);
        assert(calculatedPrice == expectedPrice);
    }

    //////////////////////////////
    // Deposit Collateral Tests 
    //////////////////////////////

    function testRevertsIfCollateralZero() external {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() external {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, COLLATERAL_AMOUNT);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(address(ranToken), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() external depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedCollateralToken = dscEngine.getTokenAmountFromUsdValue(weth, collateralValueInUsd);
        assert(totalDscMinted == expectedTotalDscMinted);
        assert(COLLATERAL_AMOUNT == expectedCollateralToken);
    }

    function testCanDepositCollateralAndMintDsc() external {
        uint256 amount = 2 ether;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), amount);
        // Caclulate the max amount of DSC that can be minted from the collateral
        uint256 dscAmountThatCanBeMinted = dscEngine.getMaxAmountOfDscThatCanBeMintedWith(weth, amount);
        dscEngine.depositCollateralAndMintDsc(weth, amount, dscAmountThatCanBeMinted);
        vm.stopPrank();
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);

        uint256 expectedCollateralToken = dscEngine.getTokenAmountFromUsdValue(weth, collateralValueInUsd);
        assert(totalDscMinted == dscAmountThatCanBeMinted);
        assert(amount == expectedCollateralToken);
    }

    //////////////////////////////
    // Redeem Collateral Tests 
    //////////////////////////////

    function testRedeemCollateralAndGetAccountInfo() external depositedCollateral {
        uint256 amount = 2 ether;
        vm.startPrank(USER);
        dscEngine.redeemCollateral(weth, amount);
        vm.stopPrank();
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedCollateralToken = dscEngine.getTokenAmountFromUsdValue(weth, collateralValueInUsd);
        assert(totalDscMinted == expectedTotalDscMinted);
        assert(COLLATERAL_AMOUNT - amount == expectedCollateralToken);
    }

    function testRedeemCollateralForDsc() external {
        
    }

    //////////////////////////////
    // Mint and Burn Tests 
    //////////////////////////////

    function testMintAndBurn() external {
        
    }

    //////////////////////////////
    // Liquidate Tests 
    //////////////////////////////

    function test
}