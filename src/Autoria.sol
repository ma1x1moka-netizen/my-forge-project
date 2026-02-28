// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;
import "./interfaces/IAutoriaEvents.sol";

contract Autoria is IAutoriaEvents {
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
    }

    // custom errors

    error Failed();
    error BalanceTooLow();
    error DealFailed();
    error RefundFailed(address sender);
    error NotEnoughDays(address sender, uint256 time);
    error NotEnoughMoney(address sender);
    error TransferFailed(address recipient, uint256 id, uint256 amount);
    error AccessDenied(address sender, uint256 time);
    error InvalidStatus(address sender);
    error InvalidDealId(uint256 id);
    error PayPledge(address sender, uint256 amount);
    error CommissionCantBeBiggerThanPrice(uint256 price, uint256 commission);

    // variables
    uint256 public dealCounter;
    //  DealData storage d = dealsId[id];

    // uint256 public carPrice = 20000 ether;
    // uint256 public arbiterComission = 200 ether;

    // mapping
    mapping(uint256 => DealData) public dealsId;

    // enum
    enum StatusData {
        Listed, // 0 (объявление создано продавцом, залог (комиссия) внесён, арбитра ещё нет)
        ArbiterAssigned, // 1 (арбитр назначен, ждём покупателя)
        Funded, // 2 (окупатель оплатил carPrice, деньги в контракте, можно решать)
        Completed, // 3 ( арбитр подтвердил сделку, выплаты прошли (продавцу + арбитру))
        Refunded, // 4 (арбитр отменил, выплаты прошли (покупателю + арбитру из залога продавца))
        Expired // 5 (дедлайн прошёл, возврат сделан)
    }

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
    function setArbiter(uint256 id) public {
        if (dealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }
        if (dealsId[id].statusData != StatusData.Listed) {
            revert InvalidStatus(msg.sender);
        }

        if (dealsId[id].arbiter != address(0)) {
            revert Failed();
        }

        if (msg.sender == dealsId[id].seller) {
            revert AccessDenied(msg.sender, block.timestamp);
        }
        dealsId[id].arbiter = msg.sender;
        dealsId[id].statusData = StatusData.ArbiterAssigned;
        emit ArbiterSet(msg.sender, id, block.timestamp);
    }

    // Оплата за тачку
    function payForCar(uint256 id) external payable {
        if (dealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }

        if (dealsId[id].arbiter == address(0)) {
            revert Failed();
        }

        if (dealsId[id].statusData != StatusData.ArbiterAssigned) {
            revert InvalidStatus(msg.sender);
        }

        if (msg.sender == dealsId[id].seller) {
            revert AccessDenied(msg.sender, block.timestamp);
        }

        if (msg.sender == dealsId[id].arbiter) {
            revert AccessDenied(msg.sender, block.timestamp);
        }

        // uint256 total = getTotalAmmount(id);

        if (msg.value != dealsId[id].carPrice) {
            revert NotEnoughMoney(msg.sender);
        }
        dealsId[id].statusData = StatusData.Funded;
        dealsId[id].buyer = msg.sender;
        dealsId[id].deadline = block.timestamp + 30 days;
        dealsId[id].amount = msg.value;

        emit Deposit(msg.sender, msg.value, block.timestamp);
    }

    // смотрим баланс (неактуально)
    // function getBalance() public view returns (uint256) {
    //     uint256 balance = address(this).balance;
    //     return balance;
    // }
    // ( bool send,) = payable(dealsId[id].seller).call{value: dealsId[id].sellerPart}("");

    // арбитр принимает решение
    function approveDeal(uint256 id, bool decision) public {
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

            (bool sendToArbiter,) = payable(dealsId[id].arbiter).call{value: dealsId[id].arbiterPart}("");
            if (sendToArbiter != true) {
                revert TransferFailed(dealsId[id].arbiter, id, dealsId[id].arbiterPart);
            }

            (bool sendToSeller,) = payable(dealsId[id].seller).call{value: dealsId[id].sellerPart}("");
            if (sendToSeller != true) {
                revert TransferFailed(dealsId[id].seller, id, dealsId[id].sellerPart);
            }

            (bool sendPledgeToSeller,) = payable(dealsId[id].seller).call{value: dealsId[id].sellersPledge}("");
            if (sendPledgeToSeller != true) {
                revert TransferFailed(dealsId[id].seller, id, dealsId[id].sellersPledge);
            }
            emit PledgeReturned(id, dealsId[id].seller, dealsId[id].sellersPledge, block.timestamp);
        } else {
            dealsId[id].statusData = StatusData.Refunded;
            emit Canceled(dealsId[id].buyer, msg.sender, id, dealsId[id].carPrice, block.timestamp);

            (bool sendToBuyer,) = payable(dealsId[id].buyer).call{value: dealsId[id].carPrice}("");
            if (sendToBuyer != true) {
                revert TransferFailed(dealsId[id].buyer, id, dealsId[id].carPrice);
            }

            (bool sendToArbiter,) = payable(dealsId[id].arbiter).call{value: dealsId[id].sellersPledge}("");
            if (sendToArbiter != true) {
                revert TransferFailed(dealsId[id].arbiter, id, dealsId[id].sellersPledge);
            }
            emit PledgeSlashed(id, dealsId[id].seller, dealsId[id].arbiter, dealsId[id].sellersPledge, block.timestamp);
        }
    }

    // прошел месяц, ни денег ни тачки, что делать?`
    function cancel(uint256 id) external {
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

        (bool refund,) = payable(dealsId[id].buyer).call{value: dealsId[id].carPrice}("");
        if (refund != true) {
            revert RefundFailed(dealsId[id].buyer);
        }

        (bool sendPledgeToSeller,) = payable(dealsId[id].seller).call{value: dealsId[id].sellersPledge}("");
        if (sendPledgeToSeller != true) {
            revert TransferFailed(dealsId[id].seller, id, dealsId[id].sellersPledge);
        }
        emit PledgeReturned(id, dealsId[id].seller, dealsId[id].sellersPledge, block.timestamp);
    }
}
