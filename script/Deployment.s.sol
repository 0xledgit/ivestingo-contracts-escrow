// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/EscrowFactory.sol";

contract DeploymentScript is Script {
    function run() public {
        vm.startBroadcast();
        address factory = address(new EscrowFactory());

        console.log("EscrowFactory deployed at:", factory);

        vm.stopBroadcast();
    }
}