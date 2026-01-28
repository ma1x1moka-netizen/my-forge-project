// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/Autoria.sol"; // 2. вот это мой контракт тут
import "../src/interfaces/IAutoriaEvents.sol";

contract AutoriaTest is Test, IAutoriaEvents {
    Autoria public autoContract; // Переменная контракта (пустая коробка)

    // Тут тестовые адреса
    address arbiter = makeAddr("arbiter");
    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");
    address robber = makeAddr("robber");
    address buyer2 = makeAddr("buyer2");

    function setUp() public {
        // вот эта лабуда должна быть везде в тестах потому, что она дает возмножность второму тесту быть если первый все поломал

        autoContract = new Autoria(arbiter, seller); //  контракт не работает без адресса арбитра, (поэтому нужно открыть его таким образом) ( это аргумент конструктора оказывается )
    }

    function testArbiterIsSet() public {
        assertEq(arbiter, autoContract.arbiter(), "arbitr invalid");
    }

    function testPayforCar() public {
        uint256 price = autoContract.carPrice();

        vm.expectEmit();
        emit Deposit(buyer, price, block.timestamp);
        vm.deal(buyer, price);
        vm.prank(buyer);
        autoContract.payforCAR{value: price}();
    }

    function testPayforCar2() public {
        vm.deal(robber, 1 ether);

        vm.expectRevert();
        vm.prank(robber);
        autoContract.payforCAR{value: 1 ether}();
    }

    //имяКонтракта.имяФункции(значение)

    function testApproved() public {
        testPayforCar();

        vm.expectEmit();

        emit Approved(arbiter, true, block.timestamp);

        vm.prank(arbiter);
        autoContract.approved(true);
    }

    function testApproved2() public {
        testPayforCar();
        vm.expectEmit();
        emit Canceled(buyer, arbiter, autoContract.carPrice(), block.timestamp);

        vm.prank(arbiter);
        autoContract.approved(false);
    }

    function testApproved3() public {
        testPayforCar();

        vm.prank(robber);

        vm.expectRevert(abi.encodeWithSelector(Autoria.AccessDenied.selector, robber));
        autoContract.approved(true);
    }

    function testCancel() public {
        testPayforCar();
        // vm.startPrank(buyer);
        vm.warp(block.timestamp + 31 days);
        uint256 balanceBefore = address(buyer).balance;
        vm.expectEmit();
        emit Canceled(buyer, buyer, autoContract.carPrice(), block.timestamp);

        vm.prank(buyer);
        autoContract.cancel();
        assert(address(autoContract).balance == 0);
        assert(balanceBefore + autoContract.carPrice() == address(buyer).balance);
        // vm.stopPrank();
    }

    // abi.encodeWithSelector--важно
    function testCancel2() public {
        testPayforCar();

        vm.prank(buyer);
        vm.warp(block.timestamp + 17 days);
        vm.expectRevert(abi.encodeWithSelector(Autoria.NotEnoughDays.selector, buyer));
        autoContract.cancel();
    }

    // тест апрува без депопизита
    function testApproved4() public {
        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidStatus.selector, arbiter));
        vm.prank(arbiter);
        autoContract.approved(true);
    }

    // тест апрува два раза к ряду
    function testApproved5() public {
        testApproved();
        // vm.warp(block.timestamp + 5 days);
        vm.prank(arbiter);
        vm.expectRevert();
        autoContract.approved(true);
    }

    // второй тест оплаты, если покупатель уже существует (уязвимость)
    function testPayforCar2x() public {
        uint256 price = autoContract.carPrice();

        testPayforCar();
        vm.deal(buyer2, price);

        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidStatus.selector, buyer2));
        vm.prank(buyer2);
        autoContract.payforCAR{value: price}();
    }
}
