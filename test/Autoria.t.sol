// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import "forge-std/Test.sol";
import "../src/Autoria.sol";
import "../src/interfaces/IAutoriaEvents.sol";

contract AutoriaTest is Test, IAutoriaEvents {
    Autoria public autoContract; // Переменная контракта (пустая коробка)

    address arbiter = makeAddr("arbiter");
    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");
    address robber = makeAddr("robber");
    address buyer2 = makeAddr("buyer2");
    error BalanceDidNotChange(address actor);

    function setUp() public {
        // вот эта лабуда должна быть везде в тестах потому, что она дает возмножность второму тесту быть если первый все поломал

        autoContract = new Autoria(arbiter, seller); //  контракт не работает без адресса арбитра, (поэтому нужно открыть его таким образом) ( это аргумент конструктора оказывается )
    }

    function testArbiterIsSet() public view {
        assertEq(arbiter, autoContract.arbiter(), "arbitr invalid");
    }

    function testPayforCar() public {
        uint256 total = autoContract.getTotalAmount();

        vm.expectEmit();
        emit Deposit(buyer, total, block.timestamp);
        vm.deal(buyer, total);
        vm.prank(buyer);
        autoContract.payforCAR{value: total}();
    }

    function testPayforCar2() public {
        vm.deal(robber, 1 ether);
        // тут нет конктрентой ошибки (тут NotEnouhMoney(msg.sender);)
        vm.expectRevert(abi.encodeWithSelector(Autoria.NotEnouhMoney.selector, robber));
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
        emit Canceled(buyer, buyer, autoContract.getTotalAmount(), block.timestamp);

        vm.prank(buyer);
        autoContract.cancel();
        assert(address(autoContract).balance == 0);
        assert(balanceBefore + autoContract.getTotalAmount() == address(buyer).balance);
        // vm.stopPrank();

        // assert(autoContract.statusData() == Autoria.StatusData.MoneyRefunded);
        assertEq(uint256(autoContract.statusData()), uint256(Autoria.StatusData.MoneyRefunded), "status invalid");
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
        // тут тоже не достает ошибки конкретной ( грешу на статус инвалид)
        vm.prank(arbiter);

        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidStatus.selector, arbiter));
        autoContract.approved(true);
    }

    // второй тест оплаты, если покупатель уже существует
    function testPayforCar2x() public {
        uint256 total = autoContract.getTotalAmount();

        testPayforCar();
        vm.deal(buyer2, total);

        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidStatus.selector, buyer2));
        vm.prank(buyer2);
        autoContract.payforCAR{value: total}();
    }

    function testpayArbiter() public {
        testPayforCar();
        vm.startPrank(arbiter);
        autoContract.approved(true);
        uint256 before = address(arbiter).balance;
        vm.expectEmit();
        emit PayArbiterDone(arbiter, autoContract.arbiterComission(), block.timestamp);
        // vm.prank(arbiter);
        autoContract.payArbiter();
        if (address(arbiter).balance - before != autoContract.arbiterComission()) {
            revert BalanceDidNotChange(arbiter);
        }
        vm.stopPrank();

        assertEq(uint256(autoContract.statusData()), uint256(Autoria.StatusData.ArbiterPaid), "status invalid");
    }

    function testpayArbiter2() public {
        testPayforCar();
        vm.startPrank(arbiter);
        autoContract.approved(false);
        uint256 before = address(arbiter).balance;
        vm.expectEmit();
        emit PayArbiterDone(arbiter, autoContract.arbiterComission(), block.timestamp);
        autoContract.payArbiter();
        if (address(arbiter).balance - before != autoContract.arbiterComission()) {
            revert BalanceDidNotChange(arbiter);
        }
        vm.stopPrank();
        assertEq(uint256(autoContract.statusData()), uint256(Autoria.StatusData.ArbiterPaid), "status invalid");
    }

    function testpayArbiter3() public {
        testPayforCar();
        vm.prank(arbiter);
        autoContract.approved(false);

        vm.expectRevert(abi.encodeWithSelector(Autoria.AccessDenied.selector, robber));
        vm.prank(robber);
        autoContract.payArbiter();
    }

    function testpayArbiter4() public {
        testPayforCar();

        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidStatus.selector, arbiter));
        vm.prank(arbiter);
        autoContract.payArbiter();
    }

    function testpayArbiter2x() public {
        testPayforCar();
        vm.startPrank(arbiter);
        autoContract.approved(true);

        autoContract.payArbiter();

        vm.expectRevert(abi.encodeWithSelector(Autoria.InvalidStatus.selector, arbiter));
        autoContract.payArbiter();
        vm.stopPrank();
    }
}
