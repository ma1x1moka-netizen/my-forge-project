// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

interface IAutoriaEvents {
    event Deposit(address indexed _buyer, uint256 _amount, uint256 time);
    event Approved(address indexed _arbiter, bool approved, uint256 time);
    event Canceled(address indexed _buyer, address actor, uint256 _amount, uint256 time);
}
