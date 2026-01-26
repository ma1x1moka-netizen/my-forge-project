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
    event Deposit(address indexed _buyer, uint256 _amount, uint256 time);
    event Approved(address indexed _arbiter, bool approved, uint256 time);
    event canceled(address indexed _buyer, address actor, uint256 _amount, uint256 time);

    // string public status;
    // uint256 public deadLine = block.timestamp + 30 days; <-- было
    uint256 public deadLine;

    constructor(address _arbiter, address _seller) {
        statusData = StatusData.Open;
        seller = _seller;
        arbiter = _arbiter;
    }

    modifier checkPay() {
        if (statusData != StatusData.Open) {
            revert InvalidStatus(msg.sender);
        }

        if (msg.value < carPrice) {
            revert NotEnouhMoney(msg.sender);
        }

        _;
    }

    modifier approvedCheck() {
        if (statusData != StatusData.Locked) {
            revert InvalidStatus(msg.sender);
        }

        if (msg.sender != arbiter) {
            revert ApproverNotValid(msg.sender);
        }

        if (address(this).balance < carPrice) {
            revert BalanceTooLow();
        }

        _;
    }

    // Оплата за тачку
    function payforCAR() external payable checkPay {
        if (statusData != StatusData.Open) {
            revert InvalidStatus(msg.sender);
        }

        if (msg.value < carPrice) {
            revert NotEnouhMoney(msg.sender);
        }

        buyer = msg.sender;

        deadLine = block.timestamp + 30 days;

        statusData = StatusData.Locked;
        emit Deposit(msg.sender, msg.value, block.timestamp);
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
            revert ApproverNotValid(msg.sender);
        }

        if (address(this).balance < carPrice) {
            revert BalanceTooLow();
        }

        if (_status == true) {
            statusData = StatusData.Finished;
            emit Approved(msg.sender, true, block.timestamp);

            (bool send, ) = address(seller).call{value: carPrice}("");

            if (send != true) {
                revert TransferFailed(seller);
            }
        } else {
            statusData = StatusData.Cancelled;
            emit canceled(buyer, msg.sender, carPrice, block.timestamp);

            (bool send, ) = address(buyer).call{value: carPrice}("");

            if (send != true) {
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
        emit canceled(buyer, msg.sender, carPrice, block.timestamp);

        (bool send, ) = address(buyer).call{value: carPrice}("");

        if (send == false) {
            revert RefundFailed(buyer);
        }
    }
}
