// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;
import "./interfaces/IAutoriaEvents.sol";

contract Autoria is IAutoriaEvents {
    error BalanceTooLow();
    error DealFailed();
    error RefundFailed(address sender);
    // error ApproverNotValid(address sender);
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

        if (msg.value != carPrice) {
            revert NotEnouhMoney(msg.sender);
        }

        _;
    }

    modifier inStatus(StatusData expectedStatus, address _user) {
        if (statusData != expectedStatus) {
            revert InvalidStatus(msg.sender);
        }

        if (msg.sender != _user) {
            revert AccessDenied(msg.sender);
        }

        _;
    }

    // Оплата за тачку
    function payforCAR() external payable checkPay {
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
    function approved(bool _status) public inStatus(StatusData.Locked, arbiter) {
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
            emit Canceled(buyer, msg.sender, carPrice, block.timestamp);

            (bool send, ) = address(buyer).call{value: carPrice}("");

            if (send != true) {
                revert TransferFailed(buyer);
            }
        }
    }

    // прошел месяц, ни денег ни тачки, что делать?
    function cancel() external inStatus(StatusData.Locked, buyer) {
        if (block.timestamp <= deadLine) {
            revert NotEnoughDays(msg.sender);
        }

        if (address(this).balance < carPrice) {
            revert BalanceTooLow();
        }
        statusData = StatusData.Cancelled;
        emit Canceled(buyer, msg.sender, carPrice, block.timestamp);

        (bool send, ) = address(buyer).call{value: carPrice}("");

        if (send == false) {
            revert RefundFailed(buyer);
        }
    }
}
