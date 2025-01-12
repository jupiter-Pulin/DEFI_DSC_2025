// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
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

pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title  DecentralizedStableCoin
 * @author Pulin
 * Collateral: Exogenous
 * Minting (Stability Mechanism): Decentralized (Algorithmic)
 * Value (Relative Stability): Anchored (Pegged to USD)
 * Collateral Type: Crypto
 *
 * This is the contract meant to be owned by DSCEngine. It is a ERC20 token that can be minted and burned by the
 *     DSCEngine smart contract.
 */
contract MockDSC is ERC20Burnable, Ownable {
    //error
    error DecentralizedStableCoin__InputAmountIsZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance(uint256);
    error DecentralizedStableCoin__IsZeroAddr();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (amount == 0) {
            revert DecentralizedStableCoin__InputAmountIsZero();
        }
        if (balance < amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance(balance);
        }
        super.burn(amount);
    }

    function mint(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) {
            revert DecentralizedStableCoin__IsZeroAddr();
        }
        if (amount == 0) {
            revert DecentralizedStableCoin__InputAmountIsZero();
        }
        _mint(to, amount);
        return false;
    }
}
