// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/EscrowFactory.sol";
import "../test/mocks/MockERC20.sol";

contract DeploymentScript is Script {
    function run() public {
        vm.startBroadcast();
        address mockBaseToken = address(new MockERC20("Mock COP", "COP"));
        address factory = address(
            new EscrowFactory(
                address(0x05703526dB38D9b2C661c9807367C14EB98b6c54)
            )
        );

        console.log("EscrowFactory deployed at:", factory);
        console.log("MockBaseToken deployed at:", mockBaseToken);

        vm.stopBroadcast();
    }
}
