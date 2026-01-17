// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {Monetta} from "../src/Monetta.sol";

contract MonettaTest is Test {
    Monetta public monetta;
    address public player = address(1); // Создаем фейкового игрока

    // Эта функция запускается ПЕРЕД каждым тестом
    function setUp() public {
        monetta = new Monetta();

        // Дадим нашему игроку немного фейкового эфира для тестов (10 ETH)
        vm.deal(player, 10 ether);

        // ВАЖНО: Дадим самому контракту эфира, чтобы он мог выплачивать выигрыши!
        // Иначе, если игрок выиграет 2х, в контракте не хватит денег на выплату (sell).
        vm.deal(address(monetta), 100 ether);
    }

    // Тест 1: Проверка игры в казино
    function testCasinoPlay() public {
        // Начинаем действовать от лица игрока
        vm.startPrank(player);

        uint256 balanceBefore = monetta.balanceOf(player);
        console.log("Balance Before:", balanceBefore);

        // Играем на 1 эфир
        monetta.casino{value: 1 ether}();

        uint256 balanceAfter = monetta.balanceOf(player);
        console.log("Balance After:", balanceAfter);

        // Мы не можем гарантировать победу (рандом), но можем проверить,
        // что либо баланс не изменился (проигрыш), либо вырос (победа)
        if (balanceAfter > balanceBefore) {
            console.log("We Won!");
            assertEq(balanceAfter, 2 ether); // Должны получить 2 токена за 1 ETH
        } else {
            console.log("We Lost!");
            assertEq(balanceAfter, 0);
        }

        vm.stopPrank();
    }

    // Тест 2: Проверка продажи токенов (Cash out)
    // Чтобы протестировать продажу, нам нужно сначала "наколдовать" игроку токены,
    // так как через казино их выиграть сложно (рандом).
    // Но так как у нас нет функции "просто дать токены", мы схитрим через "vm.mockCall"
    // или просто попытаемся выиграть в цикле, но проще протестировать логику выигрыша отдельно.

    // Давайте сделаем тест сценария: "Если у меня есть токены, могу ли я их продать?"
    // Для этого нам пришлось бы добавить функцию mint для админа в контракт,
    // но пока проверим обратную ситуацию:
    // Мы переименовали функцию (убрали Fail из названия)
    function testSellWithoutTokensReverts() public {
        vm.startPrank(player);

        // Магия тут: Мы говорим Foundry "Следующая строка ДОЛЖНА выдать ошибку"
        // Если следующая строка НЕ выдаст ошибку, тест провалится.
        vm.expectRevert();

        // Попытка продать 1 эфир токенов, когда баланс 0.
        // Это действие вызовет ошибку, и vm.expectRevert() её "поймает".
        monetta.sell(1 ether);

        vm.stopPrank();
    }
}
