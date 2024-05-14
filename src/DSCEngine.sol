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
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__CollateralTransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);

    //////////////////////////////
    // State Variables
    //////////////////////////////
    uint256 private constant MIN_HEALTH_FACTOR = 1e18; // 100% collateralised
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; 
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralised
    uint256 private constant LIQUIDATION_PRECISION = 100;


    mapping(address token => address priceFeeds) private s_priceFeeds; // token to price feeds address mapping 
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // Collateral balances of the user
    mapping(address user => uint256 dscAmountMinted) private s_dscMinted; // DSC minted by the user
    address[] private s_collateralTokens; // Collateral tokens

    DecentralisedStableCoin private i_dsc; // DSC Token

    //////////////////////////////
    // Events
    //////////////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);


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

    function depositCollateralAndMintDsc(address collateralToken, uint256 collateralAmount, address dscToken) external {
        // Deposit Collateral
    }

    /**
        @notice Deposit Collateral
        @dev This function is used to deposit collateral and mint DSC
        @param collateralToken The address of the collateral token
        @param collateralAmount The amount of collateral to deposit
     */
    function depositCollateral(
        address collateralToken,
        uint256 collateralAmount
    ) external 
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

    function redeemCollateralForDsc() external {
        // Redeem Collateral
        // Burn DSC
    }

    function redeemCollateral() external {
        // Redeem Collateral
    }

    /*
        @notice follows CEI
        @dev This function is used to mint DSC. They must have more collateral value than the amount of DSC they want to mint
        @param dscAmountToMint The amount of decentralised stablecoin to mint
     */
    function mintDsc(uint256 dscAmountToMint) external moreThanZero(dscAmountToMint) nonReentrant {
        // Mint DSC
        s_dscMinted[msg.sender] += dscAmountToMint;
        // Revert if they minted more than their collateral value
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    ///////////////////////////////////////
    // Private and Internal View Functions
    ///////////////////////////////////////

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

}