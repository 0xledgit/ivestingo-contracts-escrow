// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Escrow} from "../src/Escrow.sol";
import {EscrowFactory} from "../src/EscrowFactory.sol";
import {MockERC20} from "./Mocks/MockERC20.sol";

contract Base is Test {
    EscrowFactory public factory;
    Escrow public escrowImplementation;
    Escrow public escrow;
    MockERC20 public token;

    address public admin;
    address public pyme;
    address public expert;

    uint256 public constant PLATFORM_FEE = 500; // 5%
    uint256 public constant REVISION_PERIOD = 7 days;
    uint256 public constant TOTAL_AMOUNT = 10_000 * 1e6; // 10,000 USDC

    string[] public milestoneDescriptions;
    uint256[] public milestoneAmounts;

    function setUp() public virtual {
        admin = makeAddr("admin");
        pyme = makeAddr("pyme");
        expert = makeAddr("expert");

        vm.label(admin, "Admin");
        vm.label(pyme, "Pyme");
        vm.label(expert, "Expert");

        token = new MockERC20("USD Coin", "USDC");
        vm.label(address(token), "USDC Token");

        factory = new EscrowFactory(admin);
        vm.label(address(factory), "Escrow Factory");

        _setupMilestones();
        _deployEscrow();
        _fundAccounts();
    }

    function _setupMilestones() internal {
        milestoneDescriptions.push("Initial advance payment");
        milestoneDescriptions.push("Design phase completion");
        milestoneDescriptions.push("Development phase completion");
        milestoneDescriptions.push("Final delivery and testing");

        milestoneAmounts.push(2_500 * 1e6); // 25%
        milestoneAmounts.push(2_500 * 1e6); // 25%
        milestoneAmounts.push(2_500 * 1e6); // 25%
        milestoneAmounts.push(2_500 * 1e6); // 25%
    }

    function _deployEscrow() internal {
        vm.prank(admin);
        address escrowAddress = factory.deployEscrow(
            pyme,
            address(token),
            expert,
            TOTAL_AMOUNT,
            milestoneDescriptions,
            milestoneAmounts,
            REVISION_PERIOD,
            PLATFORM_FEE
        );

        escrow = Escrow(escrowAddress);
        vm.label(address(escrow), "Escrow Contract");
    }

    function _fundAccounts() internal {
        token.mint(pyme, TOTAL_AMOUNT * 2);
        token.mint(expert, 1_000 * 1e6);

        assertEq(token.balanceOf(pyme), TOTAL_AMOUNT * 2, "Pyme should have tokens");
        assertEq(token.balanceOf(expert), 1_000 * 1e6, "Expert should have tokens");
    }

    function _calculateNetPayment(uint256 amount) internal view returns (uint256) {
        uint256 fee = (amount * PLATFORM_FEE) / 10_000;
        return amount - fee;
    }

    function _calculateFee(uint256 amount) internal view returns (uint256) {
        return (amount * PLATFORM_FEE) / 10_000;
    }
}
