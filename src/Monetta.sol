// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "forge-std/console.sol";

contract Monetta is ERC20, ERC20Permit {
    constructor() ERC20("Monetta", "MONA") ERC20Permit("Monetta") {}

    uint256 public price;

    function buy() external payable {
        if (totalSupply() == 0) _mint(msg.sender, msg.value * 10);
        else _mint(msg.sender, (msg.value * totalSupply()) / (address(this).balance - msg.value));
    }

    function sell(uint256 tokenAmount) external {
        require(address(this).balance >= tokenAmount, "malooo");
        _burn(msg.sender, tokenAmount);
        payable(msg.sender).transfer(tokenAmount);
    }

    function random(uint256 max) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % max;
    }

    function casino() external payable {
        uint256 r = random(1000);
        console.log("Random number:", r);
        if (r < 50) _mint(msg.sender, msg.value * 2);
    }

    function casino2() external payable {
        uint256 r = random(msg.value);
        _mint(msg.sender, r);
    }

    // uint256 N = 100;

    // function randomizePrice() external {
    //     uint256 hash = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender)));
    //     uint256 hugeNumber = uint256(hash);

    //     price = hash % N;
    // }
}
