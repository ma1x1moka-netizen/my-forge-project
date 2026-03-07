// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import "forge-std/Test.sol";
import "../src/Autoria.sol";
import "../src/interfaces/IAutoriaEvents.sol";

// in progress
contract AutoriaTest is Test, IAutoriaEvents {
    Autoria public autoria; // Переменная контракта (пустая коробка)

    // adressess
    address arbiter = makeAddr("arbiter");
    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");
    address robber = makeAddr("robber");
    address buyer2 = makeAddr("buyer2");
    address buyer3 = makeAddr("buyer3");

    // constatns
    uint256 public constant CAR_PRICE = 100000 ether;
    uint256 public constant COMMISSION = 20000 ether;

    function setUp() public {
        autoria = new Autoria();
    }

    function testCreateAnnouncement() public {
        vm.startPrank(seller);

        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();
    }

    function testSetArbiter() public {
        // CreatingAnnouncement

        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();

        vm.prank(arbiter);
        autoria.setArbiter(1);
    }

    function testPayforCar() public {
        // CreatingDeal
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();
        // Making moves
        vm.deal(buyer, CAR_PRICE);
        vm.prank(buyer);
        autoria.payForCar{value: CAR_PRICE}(1);
    }

    function testAproveDeal() public {
        // CreatingDeal
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();
        // Making moves
        vm.deal(buyer, CAR_PRICE);
        vm.prank(buyer);
        autoria.payForCar{value: CAR_PRICE}(1);

        vm.startPrank(arbiter);

        autoria.setArbiter(1);
        autoria.approveDeal(1, true);
        vm.stopPrank();
    }

    function testCancel() public {
        // CreatingDeal
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();
        // Making moves
        vm.deal(buyer, CAR_PRICE);
        vm.prank(buyer);
        autoria.payForCar{value: CAR_PRICE}(1);
        vm.prank(arbiter);
        autoria.setArbiter(1);
        vm.warp(block.timestamp + 31 days);
        vm.prank(buyer);
        autoria.cancel(1);
    }
}
