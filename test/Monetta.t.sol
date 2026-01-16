// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/Monetta.sol";

contract MonettaTest is Test {
    Monetta public token;

    function setUp() public {
        token = new Monetta();
    }

    function testBuyAndSell() public {
        // 1. Создаем чистого юзера (Боба)
        address bob = address(0xB0B);

        // 2. Даем Бобу денег (10 эфиров)
        vm.deal(bob, 10 ether);

        // 3. Все действия ниже делает Боб, а не Админ
        vm.startPrank(bob);

        // --- ПОКУПКА ---
        token.buy{value: 1 ether}();

        // Теперь у Боба должен быть ровно 1 токен (так как изначально было 0)
        assertEq(token.balanceOf(bob), 1 ether, "Balance incorrect after buy");

        // --- ПРОДАЖА ---
        token.sell(1 ether);

        // Теперь токенов снова 0
        assertEq(token.balanceOf(bob), 0, "Balance incorrect after sell");

        // И деньги вернулись (было 10, потратил 1, вернул 1 = снова 10)
        assertEq(bob.balance, 10 ether, "ETH incorrect after sell");

        vm.stopPrank();
    }
}
