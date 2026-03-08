// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;
import "./interfaces/IAutoriaEvents.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Autoria is IAutoriaEvents, ReentrancyGuard {
    // Масивчик прикольный

    struct DealData {
        StatusData statusData;
        uint256 timestamp;
        uint256 amount;
        uint256 deadline;
        address seller;
        address buyer;
        address arbiter;
        uint256 carPrice;
        uint256 arbiterCommission;
        uint256 sellerPart;
        uint256 arbiterPart;
        uint256 sellersPledge;
        uint256 waitTime;
    }

    // enum
    enum StatusData {
        Listed, // 0 (объявление создано продавцом, залог (комиссия) внесён, арбитра ещё нет)
        FastPay, // 1 (покупатель назначан до арбитра, ждём)
        ArbiterAssigned, // 2 (арбитр назначен до покупателя, ждём)
        // SlowArbiterAssigned // 3 (арбитр назначен после покупателя)
        Funded, // 3 (окупатель оплатил carPrice, деньги в контракте, можно решать)
        Completed, // 4 ( арбитр подтвердил сделку, выплаты прошли (продавцу + арбитру))
        Refunded, // 5 (арбитр отменил, выплаты прошли (покупателю + арбитру из залога продавца))
        Expired // 6 (дедлайн прошёл, возврат сделан)
    }

    // custom errors

    error Failed();
    error RefundFailed(address sender);
    error NotEnoughDays(address sender, uint256 time);
    error NotEnoughMoney(address sender);
    error TransferFailed(address recipient, uint256 id, uint256 amount);
    error AccessDenied(address sender, uint256 time);
    error InvalidStatus(address sender);
    error InvalidDealId(uint256 id);
    error PayPledge(address sender, uint256 amount);
    error CommissionCantBeBiggerThanPrice(uint256 price, uint256 commission);
    error InvalidSellerAddr(address seller);
    error InvalidBuyerAddr(address buyer);
    error InvalidArbiterAddr(address arbiter);

    // constants
    uint256 public constant RESOLUTION_DEADLINE = 30 days;
    uint256 public constant ARBITER_WAITTIME = 15 days;

    // variables
    uint256 public dealCounter;
    //  DealData storage d = dealsId[id];

    // uint256 public carPrice = 20000 ether;
    // uint256 public arbiterComission = 200 ether;

    // mapping
    mapping(uint256 => DealData) public dealsId;

    // modifier onlyRole(uint256 id, address mustBe) {
    //     if (msg.sender != mustBe) {
    //         revert AccessDenied(msg.sender, block.timestamp);
    //     }
    //     _;`
    // }

    function getDealData(uint256 id) external view returns (DealData memory) {
        if (dealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }
        return dealsId[id];
    }

    // cоздаем сделку

    function createAnnouncement(uint256 price, uint256 commission) public payable {
        if (commission >= price) {
            revert CommissionCantBeBiggerThanPrice(price, commission);
        }

        if (msg.value != commission) {
            emit PayPledgeRequired(msg.sender, msg.value);
            revert PayPledge(msg.sender, msg.value);
        }
        uint256 sellersPledge = msg.value;

        dealCounter += 1;
        uint256 id = dealCounter;

        dealsId[id].sellersPledge = sellersPledge;
        dealsId[id].seller = msg.sender;
        dealsId[id].sellerPart = price - commission;
        dealsId[id].arbiterPart = commission;
        dealsId[id].carPrice = price;
        dealsId[id].arbiterCommission = commission;
        dealsId[id].statusData = StatusData.Listed;
        dealsId[id].timestamp = block.timestamp;

        emit DealCreated(id, msg.sender, price, commission, dealsId[id].sellersPledge, block.timestamp);
    }

    // определяем арбитра
    function setArbiter(uint256 id) public nonReentrant {
        if (dealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }
        if (dealsId[id].arbiter != address(0)) {
            revert Failed();
        }

        if (msg.sender == dealsId[id].seller) {
            revert AccessDenied(msg.sender, block.timestamp);
        }

        if (dealsId[id].statusData == StatusData.Listed) {
            dealsId[id].arbiter = msg.sender;
            dealsId[id].statusData = StatusData.ArbiterAssigned;
            emit ArbiterSet(msg.sender, id, block.timestamp);
        } else if (dealsId[id].statusData == StatusData.FastPay) {
            dealsId[id].arbiter = msg.sender;
            dealsId[id].statusData = StatusData.Funded;
            dealsId[id].deadline = block.timestamp + RESOLUTION_DEADLINE;
            emit ArbiterSet(msg.sender, id, block.timestamp);
        } else {
            revert InvalidStatus(msg.sender);
        }

        // if (dealsId[id].statusData != StatusData.Listed && dealsId[id].statusData != StatusData.FastPay) {
        //     revert InvalidStatus(msg.sender);
        // }

        // dealsId[id].arbiter = msg.sender;
        // dealsId[id].statusData = StatusData.ArbiterAssigned;
        // emit ArbiterSet(msg.sender, id, block.timestamp);
    }

    // Оплата за тачку
    function payForCar(uint256 id) external payable {
        if (dealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }

        if (msg.sender == dealsId[id].seller) {
            revert AccessDenied(msg.sender, block.timestamp);
        }
        if (msg.sender == dealsId[id].arbiter) {
            revert AccessDenied(msg.sender, block.timestamp);
        }

        if (msg.value != dealsId[id].carPrice) {
            revert NotEnoughMoney(msg.sender);
        }

        if (dealsId[id].statusData == StatusData.ArbiterAssigned) {
            dealsId[id].buyer = msg.sender;
            dealsId[id].amount = msg.value;
            dealsId[id].deadline = block.timestamp + RESOLUTION_DEADLINE;
            dealsId[id].statusData = StatusData.Funded;
            emit Deposit(msg.sender, msg.value, block.timestamp);
        } else if (dealsId[id].statusData == StatusData.Listed) {
            dealsId[id].waitTime = block.timestamp + ARBITER_WAITTIME;
            dealsId[id].buyer = msg.sender;
            dealsId[id].amount = msg.value;
            dealsId[id].statusData = StatusData.FastPay;
            emit Deposit(msg.sender, msg.value, block.timestamp);
        } else {
            revert InvalidStatus(msg.sender);
        }
    }

    // арбитр принимает решение
    function approveDeal(uint256 id, bool decision) public nonReentrant {
        if (dealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }

        if (dealsId[id].statusData != StatusData.Funded) {
            revert InvalidStatus(msg.sender);
        }
        if (msg.sender != dealsId[id].arbiter) {
            revert AccessDenied(msg.sender, block.timestamp);
        }

        if (decision == true) {
            dealsId[id].statusData = StatusData.Completed;
            emit Approved(dealsId[id].arbiter, id, block.timestamp);

            (bool sendToArbiter, ) = payable(dealsId[id].arbiter).call{value: dealsId[id].arbiterPart}("");
            if (sendToArbiter != true) {
                revert TransferFailed(dealsId[id].arbiter, id, dealsId[id].arbiterPart);
            }

            (bool sendToSeller, ) = payable(dealsId[id].seller).call{value: dealsId[id].sellerPart}("");
            if (sendToSeller != true) {
                revert TransferFailed(dealsId[id].seller, id, dealsId[id].sellerPart);
            }

            (bool sendPledgeToSeller, ) = payable(dealsId[id].seller).call{value: dealsId[id].sellersPledge}("");
            if (sendPledgeToSeller != true) {
                revert TransferFailed(dealsId[id].seller, id, dealsId[id].sellersPledge);
            }
            emit PledgeReturned(id, dealsId[id].seller, dealsId[id].sellersPledge, block.timestamp);
        } else {
            dealsId[id].statusData = StatusData.Refunded;
            emit Canceled(dealsId[id].buyer, msg.sender, id, dealsId[id].carPrice, block.timestamp);

            (bool sendToBuyer, ) = payable(dealsId[id].buyer).call{value: dealsId[id].carPrice}("");
            if (sendToBuyer != true) {
                revert TransferFailed(dealsId[id].buyer, id, dealsId[id].carPrice);
            }

            (bool sendToArbiter, ) = payable(dealsId[id].arbiter).call{value: dealsId[id].sellersPledge}("");
            if (sendToArbiter != true) {
                revert TransferFailed(dealsId[id].arbiter, id, dealsId[id].sellersPledge);
            }
            emit PledgeSlashed(id, dealsId[id].seller, dealsId[id].arbiter, dealsId[id].sellersPledge, block.timestamp);
        }
    }

    // прошел месяц, ни денег ни тачки, что делать?`
    function cancel(uint256 id) external nonReentrant {
        if (dealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }

        if (msg.sender != dealsId[id].buyer) {
            revert AccessDenied(msg.sender, block.timestamp);
        }

        if (dealsId[id].statusData != StatusData.Funded) {
            revert InvalidStatus(msg.sender);
        }

        if (block.timestamp <= dealsId[id].deadline) {
            revert NotEnoughDays(msg.sender, block.timestamp);
        }

        dealsId[id].statusData = StatusData.Expired;
        emit TimeCancel(dealsId[id].buyer, id, block.timestamp);

        (bool refund, ) = payable(dealsId[id].buyer).call{value: dealsId[id].carPrice}("");
        if (refund != true) {
            revert RefundFailed(dealsId[id].buyer);
        }

        (bool sendPledgeToSeller, ) = payable(dealsId[id].seller).call{value: dealsId[id].sellersPledge}("");
        if (sendPledgeToSeller != true) {
            revert TransferFailed(dealsId[id].seller, id, dealsId[id].sellersPledge);
        }
        emit PledgeReturned(id, dealsId[id].seller, dealsId[id].sellersPledge, block.timestamp);
    }

    function arbiterNotFound(uint256 id) public nonReentrant {
        if (dealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }

        if (dealsId[id].buyer == address(0)) {
            revert InvalidBuyerAddr(dealsId[id].buyer);
        }

        if (dealsId[id].arbiter != address(0)) {
            revert Failed();
        }

        if (block.timestamp < dealsId[id].waitTime) {
            revert Failed();
        }

        if (msg.sender != dealsId[id].seller && msg.sender != dealsId[id].buyer) {
            revert AccessDenied(msg.sender, block.timestamp);
        }
        dealsId[id].statusData = StatusData.Expired;
        emit TimeCancel(dealsId[id].buyer, id, block.timestamp);

        (bool refund, ) = payable(dealsId[id].buyer).call{value: dealsId[id].carPrice}("");

        if (refund != true) {
            revert RefundFailed(dealsId[id].buyer);
        }

        (bool sendPledgeToSeller, ) = payable(dealsId[id].seller).call{value: dealsId[id].sellersPledge}("");
        if (sendPledgeToSeller != true) {
            revert TransferFailed(dealsId[id].seller, id, dealsId[id].sellersPledge);
        }
        emit PledgeReturned(id, dealsId[id].seller, dealsId[id].sellersPledge, block.timestamp);
    }
}
