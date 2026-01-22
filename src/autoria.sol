// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

contract autoria {
    error BalanceTooLow();
    error DealFailed();
    error RefundFailed(address sender);
    error ApproverNotValid(address sender);
    error NotEnoughtdays(address sender);
    error NotEnouhtMoney(address sender);
    error TransferFailed(address recipient);
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
        // uint256 balanceSenderBefore = address(msg.sender).balance;

        if (msg.value < carPrice) {
            // стало <--

            revert NotEnouhtMoney(msg.sender);
        }

        // require(msg.value >= carPrice); <-- было
        buyer = msg.sender;
    }

    function getBalance() public view returns (uint256) {
        uint256 balance = address(this).balance;
        return balance;
    }

    function approved(bool _status) public {
        // require(msg.sender == arbiter, ApproverNotValid(msg.sender)); <-- Было
        if (msg.sender != arbiter) {
            // <-- Стало
            revert ApproverNotValid(msg.sender);
        }

        // require(address(this).balance >= carPrice);

        if (address(this).balance < carPrice) {
            revert BalanceTooLow();
        }

        if (_status == true) {
            uint256 balanceSellerBefore = address(seller).balance;

            (bool send, ) = address(seller).call{value: carPrice}("");

            if (balanceSellerBefore >= address(seller).balance) {
                revert TransferFailed(seller);
            }
            // require(send, "tranfer failed"); // <-- было
            if (send != true) {
                // <-- стало
                revert TransferFailed(seller);
            }
        } else {
            uint256 balanceBuyerBefore = address(buyer).balance;
            (bool send, ) = address(buyer).call{value: carPrice}("");
            // require(send, "tranfer to buyer failed"); // <-- было
            if (balanceBuyerBefore >= address(buyer).balance) {
                revert TransferFailed(buyer);
            }
            if (send != true) {
                // <-- стало
                revert TransferFailed(buyer);
            }
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

        uint256 balanceBeforeBuyer2 = address(buyer).balance;
        (bool send, ) = address(buyer).call{value: carPrice}("");
        //  !=send == send == false
        if (balanceBeforeBuyer2 >= address(buyer).balance) {
            revert RefundFailed(buyer);
        }

        if (send == false) {
            revert RefundFailed(msg.sender); //     require(send, "refund failed");
        }
    }
}
