// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

contract autoria {
    uint256 public carPrice = 20000;
    address public seller;
    address public buyer;
    address public arbiter;
    string public status;
    uint256 public deadLine = block.timestamp + 30 days;

    constructor(address _arbiter) {
        seller = msg.sender;
        arbiter = _arbiter;
    }

    function payforCAR() external payable {
        require(msg.value >= carPrice);
        buyer = msg.sender;
        if (address(this).balance == carPrice) {
            status = "locked";
        }
    }

    function getBalance() public view returns (uint256) {
        uint256 balance = address(this).balance;
        return balance;
    }

    function approved(bool _status) public {
        require(msg.sender == arbiter);
        require(address(this).balance >= carPrice);

        if (_status == true) {
            (bool send, ) = address(seller).call{value: carPrice}("");
            require(send, "AAAA");
        } else {
            (bool send, ) = address(buyer).call{value: carPrice}("");
            require(send, "AAAA");
        }
    }

    function cancel() external {
        require(block.timestamp > deadLine, "ne");
        require(address(this).balance >= carPrice);

        (bool send, ) = address(buyer).call{value: carPrice}("");
        require(send, "AAAA");
    }
}
