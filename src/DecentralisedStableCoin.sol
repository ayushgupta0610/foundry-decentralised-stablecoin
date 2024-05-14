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

import { ERC20Burnable, ERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";


/**
    @title Decentralised Stable Coin
    @author Ayush Gupta
    @dev This contract is a decentralised stable coin contract
    Collateral: Exogenous (ETH and BTC)
    Stablility: Pegged to USD
    Minting: Algorithmic

    This is the contract meant to be governed by DSCEngine. This contract is just the ERC20 implementation of our stable coin sysytem
 */
contract DecentralisedStableCoin is ERC20Burnable, Ownable {
    error DecentralisedStableCoin__MustBeMoreThanZero();
    error DecentralisedStableCoin__BurnAmountExceedsBalance();
    error DecentralisedStableCoin__NotZeroAddress();

    constructor() ERC20("Decentralised Stable Coin", "DSC") Ownable(msg.sender) { }

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (amount > balance) {
            revert DecentralisedStableCoin__BurnAmountExceedsBalance();
        }
        if (amount == 0) {
            revert DecentralisedStableCoin__MustBeMoreThanZero();
        }
        super.burn(amount);
    }

    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        if (to == address(0)) {
           revert DecentralisedStableCoin__NotZeroAddress();
        }
        if (amount == 0) {
            revert DecentralisedStableCoin__MustBeMoreThanZero();
        }
        _mint(to, amount);
        return true;
    }

}