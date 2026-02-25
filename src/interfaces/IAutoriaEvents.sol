// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

interface IAutoriaEvents {
    event Deposit(address indexed _buyer, uint256 _amount, uint256 time);
    event Approved(address indexed _arbiter, uint256 indexed id, uint256 time);
    event Canceled(address indexed _buyer, address arbiter, uint256 id, uint256 _amount, uint256 time);
    event PayArbiterDone(address indexed _arbiter, uint256 _amount, uint256 time);
    event plsPayPledge(address indexed sender, uint256 amount);
    event ArbiterSet(address indexed _arbiter, uint256 indexed id, uint256 time);
    event TimeCancel(address indexed buyer, uint256 indexed id, uint256 time);
    event DealCreated(
        uint256 indexed id, address indexed seller, uint256 price, uint256 comission, uint256 pledge, uint256 time
    );
    event PledgeReturned(uint256 indexed id, address indexed seller, uint256 amount, uint256 time);
    event PledgeSlashed(
        uint256 indexed id, address indexed seller, address indexed arbiter, uint256 amount, uint256 time
    );
}
