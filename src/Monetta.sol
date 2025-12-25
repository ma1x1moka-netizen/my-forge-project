// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";  

contract Monetta is ERC20, ERC20Permit, Ownable {
    constructor() ERC20("Monetta", "MONA") ERC20Permit("Monetta") {
        _mint(msg.sender, 1000000 * 10**18);
    }

function buy() external payable { 
    _mint(msg.sender, msg.value);
}

function sell(uint256 tokenAmount) external {
    require( address(this).balance >= tokenAmount, "malooo");
   _burn(msg.sender, tokenAmount);
payable(msg.sender).transfer(tokenAmount);


}
       




}

