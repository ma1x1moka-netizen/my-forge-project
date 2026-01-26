// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol"; // 1. что-то важное
import "../src/autoria.sol"; // 2. вот это мой контракт тут

contract AutoriaTest is Test {
    autoria public autoContract; // Переменная контракта (пустая коробка)

    // Тут тестовые адреса
    address arbiter = makeAddr("arbiter");
    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");
    address robber = makeAddr("robber");
    address buyer2 = makeAddr("buyer2");

    event Deposit(address indexed _buyer, uint256 _amount, uint256 time);
    event Approved(address indexed _arbiter, bool approved, uint256 time);
    event canceled(address indexed _buyer, address actor, uint256 _amount, uint256 time);

    function setUp() public {
        // вот эта лабуда должна быть везде в тестах потому, что она дает возмножность второму тесту быть если первый все поломал

        autoContract = new autoria(arbiter, seller); //  контракт не работает без адресса арбитра, (поэтому нужно открыть его таким образом) ( это аргумент конструктора оказывается )
    }

    function testArbiterIsSet() public {
        assertEq(arbiter, autoContract.arbiter(), "arbitr invalid");
    }

    function testPayforCar() public {
        vm.startPrank(buyer);
        vm.deal(buyer, autoContract.carPrice());
        autoContract.payforCAR{value: autoContract.carPrice()}();
        vm.stopPrank();
    }

    function testPayforCar2() public {
        vm.startPrank(robber);
        vm.expectRevert();
        vm.deal(robber, 1 ether);
        autoContract.payforCAR{value: 1 ether}();
        vm.stopPrank();
    }

    //имяКонтракта.имяФункции(значение)

    function testApproved() public {
        testPayforCar();

        vm.startPrank(arbiter);
        autoContract.approved(true);
        vm.stopPrank();
    }

    function testApproved2() public {
        testPayforCar();

        vm.startPrank(arbiter);
        autoContract.approved(false);
        // assertEq(uint256(autoContract.statusData()), 3, "statusData invalid");
        vm.stopPrank();
    }

    function testApproved3() public {
        testPayforCar();

        vm.startPrank(robber);

        vm.expectRevert(abi.encodeWithSelector(autoria.AccessDenied.selector, robber));
        autoContract.approved(true);
        vm.stopPrank();
    }

    function testCancel() public {
        testPayforCar();
        vm.startPrank(buyer);
        vm.warp(block.timestamp + 31 days);
        uint256 balanceBefore = address(buyer).balance;
        autoContract.cancel();
        assert(address(autoContract).balance == 0);
        assert(balanceBefore + autoContract.carPrice() == address(buyer).balance);
        vm.stopPrank();
    }

    // abi.encodeWithSelector--важно
    function testCancel2() public {
        testPayforCar();

        vm.startPrank(buyer);
        vm.warp(block.timestamp + 17 days);
        vm.expectRevert(abi.encodeWithSelector(autoria.NotEnoughDays.selector, buyer));
        autoContract.cancel();

        vm.stopPrank();
    }

    // тест апрува без депопизита
    function testApproved4() public {
        vm.expectRevert(abi.encodeWithSelector(autoria.InvalidStatus.selector, arbiter));
        vm.startPrank(arbiter);
        autoContract.approved(true);
        vm.stopPrank();
    }

    // тест апрува два раза к ряду
    function testApproved5() public {
        testApproved();
        // vm.warp(block.timestamp + 5 days);
        vm.startPrank(arbiter);
        vm.expectRevert();
        autoContract.approved(true);
    }

    // второй тест оплаты, если покупатель уже существует (уязвимость)
    function testPayforCar2x() public {
        uint256 price = autoContract.carPrice();

        testPayforCar();

        vm.startPrank(buyer2);
        vm.deal(buyer2, price);
        vm.expectRevert(abi.encodeWithSelector(autoria.InvalidStatus.selector, buyer2));
        autoContract.payforCAR{value: price}();
        vm.stopPrank();
    }

    function testPayforCarEmit() public {
        vm.expectEmit();

        emit Deposit(buyer, autoContract.carPrice(), block.timestamp);

        testPayforCar();
    }

    function testApprovedEmit() public {
        vm.startPrank(buyer);
        vm.deal(buyer, autoContract.carPrice());
        autoContract.payforCAR{value: autoContract.carPrice()}();
        vm.stopPrank();
        vm.startPrank(arbiter);
        vm.expectEmit();

        emit Approved(arbiter, true, block.timestamp);

        autoContract.approved(true);
        vm.stopPrank();
    }

    function testApprovedEmit2() public {
        vm.startPrank(buyer);
        vm.deal(buyer, autoContract.carPrice());
        autoContract.payforCAR{value: autoContract.carPrice()}();
        vm.stopPrank();
        vm.startPrank(arbiter);
        vm.expectEmit();

        emit canceled(buyer, arbiter, autoContract.carPrice(), block.timestamp);

        autoContract.approved(false);
        vm.stopPrank();
    }

    function testCancelemit() public {
        vm.startPrank(buyer);
        vm.deal(buyer, autoContract.carPrice());
        autoContract.payforCAR{value: autoContract.carPrice()}();
        vm.stopPrank();
        vm.startPrank(buyer);
        vm.warp(block.timestamp + 31 days);
        uint256 balanceBefore = address(buyer).balance;
        vm.expectEmit();
        emit canceled(buyer, buyer, autoContract.carPrice(), block.timestamp);

        autoContract.cancel();
        assert(address(autoContract).balance == 0);
        assert(balanceBefore + autoContract.carPrice() == address(buyer).balance);
        vm.stopPrank();
    }
}
