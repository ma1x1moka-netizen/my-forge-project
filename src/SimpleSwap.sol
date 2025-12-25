// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleSwap {
    IERC20 public immutable token;
    address public immutable owner;

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
    }

    function balanceOf(address _owner) private view returns (uint256) {
        return token.balanceOf(_owner);
    }
    // токены в ефир
    function swapTokenToEth(uint256 tokenAmount) external {
        require(tokenAmount > 0, "tokenAmount must be more than 0");

        require(token.balanceOf(msg.sender) >= tokenAmount, "MalovatoEbalov");

        token.transferFrom(msg.sender, address(this), tokenAmount);

        uint256 ethAmount = tokenAmount / 1e18;

        require(address(this).balance >= ethAmount, "malo ETH v contracte");

        payable(msg.sender).transfer(ethAmount);
    }

    // ефир в токены
    function swapEthToToken() external payable {
        require(msg.value > 0, "MalovatoEth");
        uint256 tokenAmount = msg.value / 1 ether;

        require(token.balanceOf(address(this)) >= tokenAmount, "Not enough tokens ");

        token.transfer(msg.sender, tokenAmount);
    }

    // баланс ефира
    function getContractEthBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function depositEth() external payable {}
}

