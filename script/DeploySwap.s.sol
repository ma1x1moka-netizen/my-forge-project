// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import "forge-std/Script.sol";
import "../src/EBall.sol";
import "../src/SimpleSwap.sol";
contract DeploySwap is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        EBall eball = new EBall();
        console.log("1. EBall Token deployed at: %s", address(eball));
        SimpleSwap simpleSwap = new SimpleSwap(address(eball));
        console.log("2. SimpleSwap deployed at: %s", address(simpleSwap));
        uint256 initialLiquidity = 10000 * 10 ** 18;
        eball.transfer(address(simpleSwap), initialLiquidity);
        console.log("3. Sent %s EBall tokens to SimpleSwap", initialLiquidity / 10 ** 18);
        vm.stopBroadcast();
    }
}
