// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;
import "./interfaces/IAutoriaEvents.sol";

contract Autoria is IAutoriaEvents {
    // Масивчик прикольный

    struct DealData {
        StatusData statusData;
        uint256 timestamp;
        uint256 ammount;
        uint256 deadLine;
        address seller;
        address buyer;
        address arbiter;
        uint256 carPrice;
        uint256 arbiterComission;
        uint256 sellerPart;
        uint256 arbiterPart;
        uint256 SellersPledge;
    }

    // custom erros

    error Failed();
    error BalanceTooLow();
    error DealFailed();
    error RefundFailed(address sender);
    error NotEnoughDays(address sender, uint256 time);
    error NotEnoughMoney(address sender);
    error TransferFailed(address recipient, uint256 id, uint256 ammount);
    error AccessDenied(address sender, uint256 time);
    error InvalidStatus(address sender);
    error InvalidDealId(uint256 id);
    error PayPledge(address sender, uint256 amount);
    error ComissionCantbiBiggerThanPrice(uint256 price, uint256 comission);

    // variables
    uint256 public dealCounter;
    //  DealData storage d = DealsId[id];

    // uint256 public carPrice = 20000 ether;
    // uint256 public arbiterComission = 200 ether;

    // mapping
    mapping(uint256 => DealData) public DealsId;

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

    function getdealData(uint256 id) external view returns (DealData memory) {
        if (DealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }
        return DealsId[id];
    }
    // cоздаем сделку

    function createAnnouncement(uint256 price, uint256 comission) public payable {
        if (comission >= price) {
            revert ComissionCantbiBiggerThanPrice(price, comission);
        }

        if (msg.value != comission) {
            emit plsPayPledge(msg.sender, msg.value);
            revert PayPledge(msg.sender, msg.value);
        }
        uint256 sellersPledge = msg.value;

        dealCounter += 1;
        uint256 id = dealCounter;

        DealsId[id].SellersPledge = sellersPledge;
        DealsId[id].seller = msg.sender;
        DealsId[id].sellerPart = price - comission;
        DealsId[id].arbiterPart = comission;
        DealsId[id].carPrice = price;
        DealsId[id].arbiterComission = comission;
        DealsId[id].statusData = StatusData.Listed;
        DealsId[id].timestamp = block.timestamp;

        emit DealCreated(id, msg.sender, price, comission, DealsId[id].SellersPledge, block.timestamp);
    }

    // определяем арбитра
    function setArbiter(uint256 id) public {
        if (DealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }
        if (DealsId[id].statusData != StatusData.Listed) {
            revert InvalidStatus(msg.sender);
        }

        if (DealsId[id].arbiter != address(0)) {
            revert Failed();
        }

        if (msg.sender == DealsId[id].seller) {
            revert AccessDenied(msg.sender, block.timestamp);
        }
        DealsId[id].arbiter = msg.sender;
        DealsId[id].statusData = StatusData.ArbiterAssigned;
        emit ArbiterSet(msg.sender, id, block.timestamp);
    }

    // Оплата за тачку
    function payforCAR(uint256 id) external payable {
        if (DealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }

        if (DealsId[id].arbiter == address(0)) {
            revert Failed();
        }

        if (DealsId[id].statusData != StatusData.ArbiterAssigned) {
            revert InvalidStatus(msg.sender);
        }

        if (msg.sender == DealsId[id].seller) {
            revert AccessDenied(msg.sender, block.timestamp);
        }

        if (msg.sender == DealsId[id].arbiter) {
            revert AccessDenied(msg.sender, block.timestamp);
        }

        // uint256 total = getTotalAmmount(id);

        if (msg.value != DealsId[id].carPrice) {
            revert NotEnoughMoney(msg.sender);
        }
        DealsId[id].statusData = StatusData.Funded;
        DealsId[id].buyer = msg.sender;
        DealsId[id].deadLine = block.timestamp + 30 days;
        DealsId[id].ammount = msg.value;

        emit Deposit(msg.sender, msg.value, block.timestamp);
    }

    // смотрим баланс (неактуально)
    // function getBalance() public view returns (uint256) {
    //     uint256 balance = address(this).balance;
    //     return balance;
    // }
    // ( bool send,) = payable(DealsId[id].seller).call{value: DealsId[id].sellerPart}("");

    // арбитр принимает решение
    function approved(uint256 id, bool decision) public {
        if (DealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }

        if (DealsId[id].statusData != StatusData.Funded) {
            revert InvalidStatus(msg.sender);
        }
        if (msg.sender != DealsId[id].arbiter) {
            revert AccessDenied(msg.sender, block.timestamp);
        }

        if (decision == true) {
            DealsId[id].statusData = StatusData.Completed;
            emit Approved(DealsId[id].arbiter, id, block.timestamp);

            (bool sendToArbiter,) = payable(DealsId[id].arbiter).call{value: DealsId[id].arbiterPart}("");
            if (sendToArbiter != true) {
                revert TransferFailed(DealsId[id].arbiter, id, DealsId[id].arbiterPart);
            }

            (bool sendToSeller,) = payable(DealsId[id].seller).call{value: DealsId[id].sellerPart}("");
            if (sendToSeller != true) {
                revert TransferFailed(DealsId[id].seller, id, DealsId[id].sellerPart);
            }

            (bool sendPledgeToSeller,) = payable(DealsId[id].seller).call{value: DealsId[id].SellersPledge}("");
            if (sendPledgeToSeller != true) {
                revert TransferFailed(DealsId[id].seller, id, DealsId[id].SellersPledge);
            }
            emit PledgeReturned(id, DealsId[id].seller, DealsId[id].SellersPledge, block.timestamp);
        } else {
            DealsId[id].statusData = StatusData.Refunded;
            emit Canceled(DealsId[id].buyer, msg.sender, id, DealsId[id].carPrice, block.timestamp);

            (bool sendToBuyer,) = payable(DealsId[id].buyer).call{value: DealsId[id].carPrice}("");
            if (sendToBuyer != true) {
                revert TransferFailed(DealsId[id].buyer, id, DealsId[id].carPrice);
            }

            (bool sendToArbiter,) = payable(DealsId[id].arbiter).call{value: DealsId[id].SellersPledge}("");
            if (sendToArbiter != true) {
                revert TransferFailed(DealsId[id].arbiter, id, DealsId[id].SellersPledge);
            }
            emit PledgeSlashed(id, DealsId[id].seller, DealsId[id].arbiter, DealsId[id].SellersPledge, block.timestamp);
        }
    }

    // прошел месяц, ни денег ни тачки, что делать?`
    function cancel(uint256 id) external {
        if (DealsId[id].seller == address(0)) {
            revert InvalidDealId(id);
        }

        if (msg.sender != DealsId[id].buyer) {
            revert AccessDenied(msg.sender, block.timestamp);
        }

        if (DealsId[id].statusData != StatusData.Funded) {
            revert InvalidStatus(msg.sender);
        }

        if (block.timestamp <= DealsId[id].deadLine) {
            revert NotEnoughDays(msg.sender, block.timestamp);
        }

        DealsId[id].statusData = StatusData.Expired;
        emit TimeCancel(DealsId[id].buyer, id, block.timestamp);

        (bool refund,) = payable(DealsId[id].buyer).call{value: DealsId[id].carPrice}("");
        if (refund != true) {
            revert RefundFailed(DealsId[id].buyer);
        }

        (bool sendPledgeToSeller,) = payable(DealsId[id].seller).call{value: DealsId[id].SellersPledge}("");
        if (sendPledgeToSeller != true) {
            revert TransferFailed(DealsId[id].seller, id, DealsId[id].SellersPledge);
        }
        emit PledgeReturned(id, DealsId[id].seller, DealsId[id].SellersPledge, block.timestamp);
    }
}
