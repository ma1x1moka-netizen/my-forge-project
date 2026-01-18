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

    function setUp() public {
        // вот эта лабуда должна быть везде в тестах потому, что она дает возмножность второму тесту быть если первый все поломал

        autoContract = new autoria(arbiter, seller); //  контракт не работает без адресса арбитра, (поэтому нужно открыть его таким образом) ( это аргумент конструктора оказывается )
    }

    function testArbiterIsSet() public {
        assertEq(arbiter, autoContract.arbiter(), "arbitr invalid");
    }

    function testPayforCar() public {
        vm.startPrank(buyer);
        vm.deal(buyer, 20000 ether);
        autoContract.payforCAR{value: 20000 ether}();
        vm.stopPrank();
    }

    function testPayforCar2() public {
        vm.startPrank(robber);
        vm.expectRevert();
        vm.deal(robber, 10 ether);
        autoContract.payforCAR{value: 1 ether}();
        vm.stopPrank();
    }

    //имяКонтракта.имяФункции(значение)

    function testAproved() public {
        testPayforCar();

        vm.startPrank(arbiter);
        autoContract.approved(true);
        vm.stopPrank();
    }

    function testAproved2() public {
        testPayforCar();

        vm.startPrank(arbiter);
        autoContract.approved(false);
        vm.stopPrank();
    }

    function testAproved3() public {
        testPayforCar();

        vm.startPrank(robber);
        vm.expectRevert();
        autoContract.approved(true);
        vm.stopPrank();
    }

    function testCancel() public {
        testPayforCar();
        vm.warp(block.timestamp + 31 days);
        uint256 balanceBefore = address(buyer).balance;
        autoContract.cancel();
        assert(address(autoContract).balance == 0);
        assert(balanceBefore + 20000 ether == address(buyer).balance);
    }
}
