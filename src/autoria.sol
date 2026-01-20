// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

contract autoria {
    error BalanceTooLow();
    error DealFailed();
    error RefundFailed(address sender);
    error ApproverNotValid(address sender);
    error NotEnoughtdays(address sender);
    uint256 public carPrice = 20000 ether;
    address public seller;
    address public buyer;
    address public arbiter;
    // string public status;
    uint256 public deadLine = block.timestamp + 30 days;

    constructor(address _arbiter, address _seller) {
        seller = _seller;
        arbiter = _arbiter;
    }

    function payforCAR() external payable {
        require(msg.value >= carPrice);
        buyer = msg.sender;
        if (address(this).balance == carPrice) {
            // status = "locked";
        }
    }

    function getBalance() public view returns (uint256) {
        uint256 balance = address(this).balance;
        return balance;
    }

    function approved(bool _status) public {
        require(msg.sender == arbiter, ApproverNotValid(msg.sender));
        require(address(this).balance >= carPrice);

        if (_status == true) {
            (bool send, ) = address(seller).call{value: carPrice}("");
            require(send, "tranfer failed");
        } else {
            (bool send, ) = address(buyer).call{value: carPrice}("");
            require(send, "tranfer to buyer failed");
        }
    }

    function cancel() external {
        if (block.timestamp <= deadLine) {
            revert NotEnoughtdays(msg.sender);
        }

        // require(block.timestamp > deadLine, "deal failed");

        // require(address(this).balance >= carPrice);
        if (address(this).balance < carPrice) {
            revert BalanceTooLow();
        }

        (bool send, ) = address(buyer).call{value: carPrice}("");
        //  !=send == send == false
        if (send == false) {
            revert RefundFailed(msg.sender); //     require(send, "refund failed");
        }
    }
}
