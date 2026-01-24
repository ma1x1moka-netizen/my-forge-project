// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

contract autoria {
    error BalanceTooLow();
    error DealFailed();
    error RefundFailed(address sender);
    error ApproverNotValid(address sender);
    error NotEnoughDays(address sender);
    error NotEnouhMoney(address sender);
    error TransferFailed(address recipient);
    error AccessDenied(address sender);
    error InvalidStatus(address sender);
    uint256 public carPrice = 20000 ether;
    address public seller;
    address public buyer;
    address public arbiter;

    enum StatusData {
        Open,
        Locked,
        Finished,
        Cancelled
    }
    StatusData public statusData;

    // string public status;
    // uint256 public deadLine = block.timestamp + 30 days; <-- было
    uint256 public deadLine;

    constructor(address _arbiter, address _seller) {
        statusData = StatusData.Open;
        seller = _seller;
        arbiter = _arbiter;
    }
    // Оплата за тачку
    function payforCAR() external payable {
        if (statusData != StatusData.Open) {
            revert InvalidStatus(msg.sender);
        }

        if (msg.value < carPrice) {
            revert NotEnouhMoney(msg.sender);
        }

        buyer = msg.sender;

        deadLine = block.timestamp + 30 days;

        statusData = StatusData.Locked;
    }
    // смотрим баланс
    function getBalance() public view returns (uint256) {
        uint256 balance = address(this).balance;
        return balance;
    }
    // арбитр принимает решение
    function approved(bool _status) public {
        if (statusData != StatusData.Locked) {
            revert InvalidStatus(msg.sender);
        }

        if (msg.sender != arbiter) {
            // <-- Стало
            revert ApproverNotValid(msg.sender);
        }
        // statusData = StatusData.Finished;

        if (address(this).balance < carPrice) {
            revert BalanceTooLow();
        }

        if (_status == true) {
            uint256 balanceSellerBefore = address(seller).balance;

            statusData = StatusData.Finished;

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
            statusData = StatusData.Cancelled;

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
    // прошел месяц, ни денег ни тачки, что делать?
    function cancel() external {
        if (statusData != StatusData.Locked) {
            revert InvalidStatus(msg.sender);
        }

        if (msg.sender != buyer) {
            revert AccessDenied(msg.sender);
        }

        if (block.timestamp <= deadLine) {
            revert NotEnoughDays(msg.sender);
        }

        if (address(this).balance < carPrice) {
            revert BalanceTooLow();
        }
        statusData = StatusData.Cancelled;
        uint256 balanceBeforeBuyer2 = address(buyer).balance;
        (bool send, ) = address(buyer).call{value: carPrice}("");

        if (send == false) {
            revert RefundFailed(msg.sender);
        }

        if (balanceBeforeBuyer2 >= address(buyer).balance) {
            revert RefundFailed(buyer);
        }
    }
}
