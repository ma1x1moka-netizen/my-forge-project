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

    