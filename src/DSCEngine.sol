// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-license-identifier: MIT
pragma solidity ^0.8.19;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { DecentralisedStableCoin } from "./DecentralisedStableCoin.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


/**
    @title Decentralised Stable Coin Engine
    @author Ayush Gupta
    @dev This contract is a decentralised stable coin contract
    Collateral: Exogenous (ETH and BTC)
    Stablility: Pegged to USD
    Minting: Algorithmic

    This is the contract meant to be governed by DSCEngine. This contract is just the ERC20 implementation of our stable coin sysytem
 */
contract DSCEngine is ReentrancyGuard {

    //////////////////////////////
    // Errors
    //////////////////////////////
    error DSCEngine__MintFailed();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__CollateralTransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    //////////////////////////////
    // State Variables
    //////////////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; 
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralised
    uint256 private constant LIQUIDATION_PRECISION = 100; // for pecentage
    uint256 private constant MIN_HEALTH_FACTOR = 1e18; // 100% collateralised
    uint256 private constant LIQUIDATION_BONUS = 10; // this means a 10% bonus



    mapping(address token => address priceFeeds) private s_priceFeeds; // token to price feeds address mapping 
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // Collateral balances of the user
    mapping(address user => uint256 dscAmountMinted) private s_dscMinted; // DSC minted by the user
    address[] private s_collateralTokens; // Collateral tokens

    DecentralisedStableCoin private i_dsc; // DSC Token

    //////////////////////////////
    // Events
    //////////////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount);


    //////////////////////////////
    // Modifiers
    //////////////////////////////
    modifier moreThanZero(uint256 amount) {
        if(amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if(s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    //////////////////////////////
    // External Functions
    //////////////////////////////
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        if(tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // For example ETH / USD, BTC / USD, etc
        for(uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }   

        i_dsc = DecentralisedStableCoin(dscAddress);
    }

    /**
        @notice Deposit Collateral and Mint DSC
        @dev This function is used to deposit collateral and mint DSC
        @param collateralToken The address of the collateral token
        @param collateralAmount The amount of collateral to deposit
        @param dscAmountToMint The amount of DSC to mint
     */
    function depositCollateralAndMintDsc(address collateralToken, uint256 collateralAmount, uint256 dscAmountToMint) external {
        // Deposit Collateral
        depositCollateral(collateralToken, collateralAmount);
        // Mint DSC
        mintDsc(dscAmountToMint);
    }

    /**
        @notice Deposit Collateral
        @dev This function is used to deposit collateral
        @param collateralToken The address of the collateral token
        @param collateralAmount The amount of collateral to deposit
     */
    function depositCollateral(
        address collateralToken,
        uint256 collateralAmount
    ) public 
        moreThanZero(collateralAmount)
        isAllowedToken(collateralToken)
        nonReentrant {
        // Deposit Collateral
        s_collateralDeposited[msg.sender][collateralToken] += collateralAmount;
        emit CollateralDeposited(msg.sender, collateralToken, collateralAmount);
        bool success = IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);
        if (!success) {
            revert DSCEngine__CollateralTransferFailed();
        }
    }

    /**
        @notice Redeem Collateral and Burn DSC
        @dev This function is used to redeem collateral and burn DSC
        @param collateralToken The address of the collateral token
        @param collateralAmount The amount of collateral to redeem
        @param dscAmountToBurn The amount of DSC to burn
     */
    function redeemCollateralForDsc(address collateralToken, uint256 collateralAmount, uint256 dscAmountToBurn) external {
        // Burn DSC
        burnDsc(dscAmountToBurn);
        // Redeem Collateral (take note of the order of these two functions)
        redeemCollateral(collateralToken, collateralAmount);
        // Redeem Collateral already checks for health factor
    }

    // in order to redeem collateral:
    // 1. Health factor must be above 1 AFTER collateral pulled
    // 2. Burn DSC accordingly
    // 3. Transfer/Redeem collateral back to user
    function redeemCollateral(address collateralToken, uint256 collateralAmount) 
        public
        moreThanZero(collateralAmount)
        nonReentrant {
        // Redeem Collateral
        _redeemCollateral(msg.sender, msg.sender, collateralToken, collateralAmount);
        _revertIfHealthFactorIsBroken(msg.sender); // to be done after collateral is pulled
    }

    /*
        @notice follows CEI
        @dev This function is used to mint DSC. They must have more collateral value than the amount of DSC they want to mint
        @param dscAmountToMint The amount of decentralised stablecoin to mint
     */
    function mintDsc(uint256 dscAmountToMint) public moreThanZero(dscAmountToMint) nonReentrant {
        // Mint DSC
        s_dscMinted[msg.sender] += dscAmountToMint;
        // Revert if they minted more than their collateral value
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, dscAmountToMint);

        if (minted != true) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc(uint256 dscAmountToBurn) public moreThanZero(dscAmountToBurn) nonReentrant {
        _burnDsc(msg.sender, msg.sender, dscAmountToBurn);
        _revertIfHealthFactorIsBroken(msg.sender); // Not sure if this is needed
    }


    // $75 backing $50 of DSC
    // Liquidator takes $75 of collateral and burns off the $50 of DSC

    // If we do start nearing liquidation, we want someone to liquidate positions
    // If someone is almost undercollateralised, we will pay you to liquidate them
    /*
        @notice Liquidate a user
        @dev This function is used to liquidate a user
        @param collateralToken The address of the collateral token to liquidate from the user
        @param user The address of the user who has broken the health factor. Their _healthFactor should be below MIN_HEALTH_FACTOR
        @param debtToCover The amount of DSC you want to burn to improve the users health factor
        @notice You can partially liquidate a user
        @notice You will get liquidation bonus for taking the users funds
        @notice This function working assumes the protocol will be roughly 200% overcollateralised in order for this to work
        @notice This function will revert if the user is not undercollateralised
        @notice A known bug would be if the protocol were 100% or less collateralised, then we wouldn't be able to incentivise the liquidators
        For example, if the price of the collateral plummeted, before anyone could be liquidated
     */
    function liquidate(address collateralToken, address user, uint256 debtToCover) 
        external
        moreThanZero(debtToCover)
        nonReentrant {
            // need to check the health factor of the user
            uint256 startingUserHealthFactor = _healthFactor(user);
            if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
                revert DSCEngine__HealthFactorOk();
            }
            // We want to burn their DSC "debt"
            // And take their collateral
            // Bad user: $140 ETH, $100 DSC
            // debtToCover = $100
            // $100 DSC == ?? ETH
            uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsdValue(collateralToken, debtToCover);
            // And give them a 10% bonus
            // So, we're giving the liquidator $110 of WETH for 100 DSC
            // We should implement a feature to liquidate in the event the protocol is solvent
            // And sweep extra amounts into a treasury
        
            // 0.05 * 0.1 = 0.005. Getting 0.055
            uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
            uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
            // Redeem Collateral
            _redeemCollateral(user, msg.sender, collateralToken, totalCollateralToRedeem);
            // Burn DSC
            _burnDsc(user, msg.sender, debtToCover);

            uint256 endingUserHealthFactor = _healthFactor(user);
            if(endingUserHealthFactor <= startingUserHealthFactor) {
                revert DSCEngine__HealthFactorNotImproved();
            }
            _revertIfHealthFactorIsBroken(msg.sender);
    }

    ///////////////////////////////////////
    // Private and Internal View Functions
    ///////////////////////////////////////

    /*
        @dev Low level internal function; do not call this until the function calling this is 
        checking for healthFactorBeingBroken
    */
    function _burnDsc(address dscFrom, address onBehalfOf, uint256 dscAmountToBurn) private {
         // Burn DSC
        s_dscMinted[onBehalfOf] -= dscAmountToBurn;
        // transfer and burn DSC
        bool success = i_dsc.transferFrom(dscFrom, address(this), dscAmountToBurn);
        if (!success) {
            revert DSCEngine__CollateralTransferFailed();
        }
        i_dsc.burn(dscAmountToBurn);
    }

    function _redeemCollateral(address from, address to, address collateralToken, uint256 collateralAmount) private {
        // Redeem Collateral
         s_collateralDeposited[from][collateralToken] -= collateralAmount;
        emit CollateralRedeemed(from, to, collateralToken, collateralAmount);
        bool success = IERC20(collateralToken).transfer(to, collateralAmount);
        if (!success) {
            revert DSCEngine__CollateralTransferFailed();
        }
    }

    /*
        @dev Returns the total DSC minted and the total collateral value in USD
        @param user The address of the user
        @return The total DSC minted and the total collateral value in USD
     */
    function _getAccountInformation(address user) private view returns (uint256 totalDscMinted, uint256 collateralValueInUsd) {
        totalDscMinted = s_dscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /*
        @dev Returns how close to liquidation a user is. If the user goes below 1, they can get liquidated
        @param user The address of the user
        @return The health factor of the user
     */
    function _healthFactor(address user) private view returns (uint256) {
        // total DSC minted
        // total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        // $1000 ETH / 100 DSC minted
        // 1000 * 50 = 50000 / 100 = 500 / 100 > 1
        return collateralAdjustedForThreshold * PRECISION / totalDscMinted;
    }
    
    // 1. Check is the user has enough collateral value
    // 2. If they don't, revert
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ///////////////////////////////////////
    // Public and External View Functions
    ///////////////////////////////////////

    function getTokenAmountFromUsdValue(address collateralToken, uint256 usdAmountInWei) public view returns (uint256) {
        // Get the price of the token in USD
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[collateralToken]);
        (, int256 price, , , ) = priceFeed.latestRoundData(); // Decimals are 8

        // The return value from chainlink will be 1000 * 1e8
        return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for(uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        // Get the price of the token in USD
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData(); // Decimals are 8

        // The return value from chainlink will be 1000 * 1e8
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getAccountInformation(address user) external view returns (uint256 totalDscMinted, uint256 collateralValueInUsd) {
        return _getAccountInformation(user);
    }

    function getMaxAmountOfDscThatCanBeMintedWith(address collateralToken, uint256 collateralAmount) external view returns (uint256) {
        // Get the price of the token in USD
        uint256 collateralValueInUsd = getUsdValue(collateralToken, collateralAmount);
        // Calculate the health factor considering this to be a new user
        return (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
    }

}