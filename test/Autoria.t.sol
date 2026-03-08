// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import "forge-std/Test.sol";
import "../src/Autoria.sol";
import "../src/interfaces/IAutoriaEvents.sol";

// happy path

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

    // test Creating Deal
    function testCreateAnnouncement() public {
        vm.expectEmit();
        emit DealCreated(1, seller, CAR_PRICE, COMMISSION, COMMISSION, block.timestamp);
        vm.startPrank(seller);

        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();

        assertEq(autoria.dealCounter(), 1);
        Autoria.DealData memory get = autoria.getDealData(1);
        assertEq(uint256(get.statusData), 0);
        assertEq(get.carPrice, CAR_PRICE);
        assertEq(get.arbiterCommission, COMMISSION);
        assertEq(get.sellersPledge, COMMISSION);
        assertEq(address(autoria).balance, COMMISSION);
    }

    //test seting arbiter
    function testSetArbiter() public {
        // CreatingAnnouncement
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();

        vm.expectEmit();
        emit ArbiterSet(arbiter, 1, block.timestamp);
        vm.prank(arbiter);
        autoria.setArbiter(1);
        Autoria.DealData memory get = autoria.getDealData(1);
        assertEq(get.arbiter, arbiter);
        assertEq(uint256(get.statusData), 2);
    }

    //test FastPay seting arbiter
    function testFastSetArbiter() public {
        // CreatingAnnouncement
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();

        // paying for car
        vm.deal(buyer, CAR_PRICE);
        vm.prank(buyer);
        autoria.payForCar{value: CAR_PRICE}(1);
        // seting arbiter

        vm.expectEmit();
        emit ArbiterSet(arbiter, 1, block.timestamp);
        vm.prank(arbiter);
        autoria.setArbiter(1);
        Autoria.DealData memory get = autoria.getDealData(1);
        assertEq(get.arbiter, arbiter);
        assertEq(uint256(get.statusData), 3);
    }

    // test FastPayForCar
    function testFastPayforCar() public {
        // CreatingDeal
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();
        // Making moves
        vm.expectEmit();
        emit Deposit(buyer, CAR_PRICE, block.timestamp);
        vm.deal(buyer, CAR_PRICE);
        vm.prank(buyer);
        autoria.payForCar{value: CAR_PRICE}(1);
        Autoria.DealData memory get = autoria.getDealData(1);
        assertEq(get.buyer, buyer);
        assertEq(uint256(get.statusData), 1);
    }

    // test PayForCar
    function testPayforCar() public {
        // CreatingDeal
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();
        // seting arbiter
        vm.prank(arbiter);
        autoria.setArbiter(1);

        // Making moves

        vm.expectEmit();
        emit Deposit(buyer, CAR_PRICE, block.timestamp);
        vm.deal(buyer, CAR_PRICE);
        vm.prank(buyer);
        autoria.payForCar{value: CAR_PRICE}(1);
        Autoria.DealData memory get = autoria.getDealData(1);
        assertEq(get.buyer, buyer);
        assertEq(uint256(get.statusData), 3);
    }

    // test fastPayApprove
    function testAproveDeal() public {
        uint256 sellerBefore = seller.balance;
        uint256 arbiterBefore = arbiter.balance;

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
        vm.expectEmit();
        emit Approved(arbiter, 1, block.timestamp);
        autoria.approveDeal(1, true);
        vm.stopPrank();

        assertEq(uint256(autoria.getDealData(1).statusData), 4);
        assertEq(seller.balance, sellerBefore + (CAR_PRICE - COMMISSION) + COMMISSION);
        assertEq(arbiter.balance, arbiterBefore + COMMISSION);
        assertEq(address(autoria).balance, 0);
    }

    // test fastPayApprove(false)
    function testAproveDeal_false() public {
        uint256 arbiterBefore = arbiter.balance;

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
        vm.expectEmit();
        emit Canceled(buyer, arbiter, 1, CAR_PRICE, block.timestamp);
        autoria.approveDeal(1, false);
        vm.stopPrank();

        assertEq(uint256(autoria.getDealData(1).statusData), 5);
        assertEq(arbiter.balance, arbiterBefore + COMMISSION);
        assertEq(address(autoria).balance, 0);
    }

    // test fastPay cancel
    function testCancel() public {
        uint256 buyerBalanceBefore = address(buyer).balance;
        uint256 sellerBalanceBefore = address(seller).balance;

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
        vm.expectEmit();
        emit TimeCancel(buyer, 1, block.timestamp);
        autoria.cancel(1);
        assertEq(address(buyer).balance, buyerBalanceBefore + CAR_PRICE);
        assertEq(address(seller).balance, sellerBalanceBefore + COMMISSION);
        assertEq(address(autoria).balance, 0);
        assertEq(uint256(autoria.getDealData(1).statusData), 6);
    }

    //CommissionCantBeBiggerThanPrice
    // test Creating Deal
    function testCreateAnnouncement_comissionBiggerThanPrice() public {
        // vm.expectEmit();
        // emit DealCreated(1, seller, CAR_PRICE, COMMISSION, COMMISSION, block.timestamp);
        vm.startPrank(seller);

        vm.deal(seller, 20 ether);
        vm.expectRevert(abi.encodeWithSelector(Autoria.CommissionCantBeBiggerThanPrice.selector, 14 ether, 20 ether));
        autoria.createAnnouncement{value: 20 ether}(14 ether, 20 ether);
        vm.stopPrank();
    }

    function testPayForCar_revert_withoutArbiter() public {
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();

        vm.deal(buyer, CAR_PRICE);
        vm.prank(buyer);

        autoria.payForCar{value: CAR_PRICE}(1);
    }

    function testPayForCar_revert_wrongAmount() public {
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();

        vm.prank(arbiter);
        autoria.setArbiter(1);

        vm.deal(buyer, CAR_PRICE);
        vm.prank(buyer);
        vm.expectRevert();
        autoria.payForCar{value: CAR_PRICE - 1}(1);
    }

    function testCancel_revert_beforeDeadline() public {
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();

        vm.prank(arbiter);
        autoria.setArbiter(1);

        vm.deal(buyer, CAR_PRICE);
        vm.prank(buyer);
        autoria.payForCar{value: CAR_PRICE}(1);

        vm.prank(buyer);
        vm.expectRevert();
        autoria.cancel(1);
    }

    function testCancel_revert_notBuyer() public {
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();

        vm.prank(arbiter);
        autoria.setArbiter(1);

        vm.deal(buyer, CAR_PRICE);
        vm.prank(buyer);
        autoria.payForCar{value: CAR_PRICE}(1);

        vm.warp(block.timestamp + 31 days);
        vm.prank(robber);
        vm.expectRevert();
        autoria.cancel(1);
    }

    function testAproveDea_AccessDenied() public {
        // CreatingDeal
        vm.startPrank(seller);
        vm.deal(seller, COMMISSION);
        autoria.createAnnouncement{value: COMMISSION}(CAR_PRICE, COMMISSION);
        vm.stopPrank();
        // Making moves
        vm.deal(buyer, CAR_PRICE);
        vm.prank(buyer);
        autoria.payForCar{value: CAR_PRICE}(1);

        autoria.setArbiter(1);
        vm.expectRevert(abi.encodeWithSelector(Autoria.AccessDenied.selector, seller, 1));
        vm.prank(seller);
        autoria.approveDeal(1, true);

        assertEq(uint256(autoria.getDealData(1).statusData), 3);
        assertEq(address(autoria).balance, CAR_PRICE + COMMISSION);
    }
}
