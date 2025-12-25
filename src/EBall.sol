// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract EBall is ERC20, ERC20Permit {
    address public owner;
    
    
    
    
    
    constructor() ERC20("EBall", "EBL") ERC20Permit("EBall") {
        owner = msg.sender;

        _mint(msg.sender, 1000000 * 10**18);
    }
}