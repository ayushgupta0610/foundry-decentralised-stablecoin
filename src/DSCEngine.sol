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
pragma solidity ^0.8.20;


/**
    @title Decentralised Stable Coin Engine
    @author Ayush Gupta
    @dev This contract is a decentralised stable coin contract
    Collateral: Exogenous (ETH and BTC)
    Stablility: Pegged to USD
    Minting: Algorithmic

    This is the contract meant to be governed by DSCEngine. This contract is just the ERC20 implementation of our stable coin sysytem
 */
contract DSCEngine {}