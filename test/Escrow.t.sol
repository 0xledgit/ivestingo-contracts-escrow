// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Base} from "./Base.sol";
import {EscrowInterface} from "../src/interfaces/EscrowInterface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EscrowTest is Base {

    // ============================================
    // FUND TESTS
    // ============================================

    function testFund_Success() public {
        vm.startPrank(pyme);
        token.approve(address(escrow), TOTAL_AMOUNT);

        uint256 pymeBalanceBefore = token.balanceOf(pyme);
        uint256 escrowBalanceBefore = token.balanceOf(address(escrow));

        escrow.fund();

        assertEq(uint256(escrow.status()), uint256(EscrowInterface.EscrowStatus.Funded), "Status should be Funded");
        assertEq(token.balanceOf(pyme), pymeBalanceBefore - TOTAL_AMOUNT, "Pyme balance should decrease");
        assertEq(token.balanceOf(address(escrow)), escrowBalanceBefore + TOTAL_AMOUNT, "Escrow balance should increase");
        vm.stopPrank();
    }

    function testFund_RevertIfNotPyme() public {
        vm.prank(expert);
        vm.expectRevert("Only pyme");
        escrow.fund();
    }

    function testFund_RevertIfNotCreatedState() public {
        vm.startPrank(pyme);
        token.approve(address(escrow), TOTAL_AMOUNT);
        escrow.fund();

        vm.expectRevert("Not in created state");
        escrow.fund();
        vm.stopPrank();
    }

    function testFund_RevertIfNoApproval() public {
        vm.prank(pyme);
        vm.expectRevert();
        escrow.fund();
    }

    // ============================================
    // ACCEPT CONTRACT TESTS
    // ============================================

    function testAcceptContract_Success() public {
        vm.startPrank(pyme);
        token.approve(address(escrow), TOTAL_AMOUNT);
        escrow.fund();
        vm.stopPrank();

        uint256 milestone0Amount = milestoneAmounts[0];
        uint256 totalPlatformFee = _calculateFee(TOTAL_AMOUNT);
        uint256 netPayment = _calculateNetPayment(milestone0Amount);

        uint256 expertBalanceBefore = token.balanceOf(expert);
        uint256 adminBalanceBefore = token.balanceOf(admin);

        vm.prank(expert);
        escrow.acceptContract();

        assertEq(uint256(escrow.status()), uint256(EscrowInterface.EscrowStatus.Active), "Status should be Active");
        assertEq(escrow.currentMilestone(), 1, "Current milestone should be 1");
        assertEq(token.balanceOf(expert), expertBalanceBefore + netPayment, "Expert should receive net payment");
        assertEq(token.balanceOf(admin), adminBalanceBefore + totalPlatformFee, "Admin should receive total fee");

        EscrowInterface.Milestone memory milestone = escrow.getMilestone(0);
        assertEq(uint256(milestone.status), uint256(EscrowInterface.MilestoneStatus.Approved), "Milestone 0 should be approved");
    }

    function testAcceptContract_RevertIfNotExpert() public {
        vm.startPrank(pyme);
        token.approve(address(escrow), TOTAL_AMOUNT);
        escrow.fund();
        vm.stopPrank();

        vm.prank(pyme);
        vm.expectRevert("Only expert");
        escrow.acceptContract();
    }

    function testAcceptContract_RevertIfNotFunded() public {
        vm.prank(expert);
        vm.expectRevert("Not funded");
        escrow.acceptContract();
    }

    // ============================================
    // DELIVER MILESTONE TESTS
    // ============================================

    function testDeliverMilestone_Success() public {
        _fundAndAcceptContract();

        vm.prank(expert);
        escrow.deliverMilestone();

        EscrowInterface.Milestone memory milestone = escrow.getMilestone(1);
        assertEq(uint256(milestone.status), uint256(EscrowInterface.MilestoneStatus.Delivered), "Milestone should be delivered");
        assertGt(milestone.deliveryTimestamp, 0, "Delivery timestamp should be set");
    }

    function testDeliverMilestone_RevertIfNotExpert() public {
        _fundAndAcceptContract();

        vm.prank(pyme);
        vm.expectRevert("Only expert");
        escrow.deliverMilestone();
    }

    function testDeliverMilestone_RevertIfNotActive() public {
        vm.prank(expert);
        vm.expectRevert("Not active");
        escrow.deliverMilestone();
    }

    function testDeliverMilestone_RevertIfAlreadyDelivered() public {
        _fundAndAcceptContract();

        vm.startPrank(expert);
        escrow.deliverMilestone();

        vm.expectRevert("Milestone not in progress");
        escrow.deliverMilestone();
        vm.stopPrank();
    }

    // ============================================
    // APPROVE MILESTONE TESTS
    // ============================================

    function testApproveMilestone_Success() public {
        _fundAndAcceptContract();

        vm.prank(expert);
        escrow.deliverMilestone();

        uint256 milestone1Amount = milestoneAmounts[1];
        uint256 netPayment = _calculateNetPayment(milestone1Amount);
        uint256 expertBalanceBefore = token.balanceOf(expert);

        vm.prank(pyme);
        escrow.approveMilestone();

        assertEq(escrow.currentMilestone(), 2, "Current milestone should be 2");
        assertEq(token.balanceOf(expert), expertBalanceBefore + netPayment, "Expert should receive payment");

        EscrowInterface.Milestone memory milestone = escrow.getMilestone(1);
        assertEq(uint256(milestone.status), uint256(EscrowInterface.MilestoneStatus.Approved), "Milestone should be approved");
    }

    function testApproveMilestone_RevertIfNotPyme() public {
        _fundAndAcceptContract();

        vm.prank(expert);
        escrow.deliverMilestone();

        vm.prank(expert);
        vm.expectRevert("Only pyme");
        escrow.approveMilestone();
    }

    function testApproveMilestone_RevertIfNotDelivered() public {
        _fundAndAcceptContract();

        vm.prank(pyme);
        vm.expectRevert("Not delivered");
        escrow.approveMilestone();
    }

    function testApproveMilestone_CompletesContract() public {
        _fundAndAcceptContract();

        // Approve milestones 1, 2, and 3 (0 was auto-approved)
        for (uint256 i = 1; i < 4; i++) {
            vm.prank(expert);
            escrow.deliverMilestone();

            vm.prank(pyme);
            escrow.approveMilestone();
        }

        assertEq(uint256(escrow.status()), uint256(EscrowInterface.EscrowStatus.Completed), "Status should be Completed");
    }

    // ============================================
    // REJECT MILESTONE TESTS
    // ============================================

    function testRejectMilestone_Success() public {
        _fundAndAcceptContract();

        vm.prank(expert);
        escrow.deliverMilestone();

        vm.prank(pyme);
        escrow.rejectMilestone();

        EscrowInterface.Milestone memory milestone = escrow.getMilestone(1);
        assertEq(uint256(milestone.status), uint256(EscrowInterface.MilestoneStatus.InProgress), "Milestone should be in progress");
        assertEq(milestone.deliveryTimestamp, 0, "Delivery timestamp should be reset");
    }

    function testRejectMilestone_RevertIfNotPyme() public {
        _fundAndAcceptContract();

        vm.prank(expert);
        escrow.deliverMilestone();

        vm.prank(expert);
        vm.expectRevert("Only pyme");
        escrow.rejectMilestone();
    }

    function testRejectMilestone_RevertIfNotDelivered() public {
        _fundAndAcceptContract();

        vm.prank(pyme);
        vm.expectRevert("Not delivered");
        escrow.rejectMilestone();
    }

    function testRejectMilestone_AllowsRedelivery() public {
        _fundAndAcceptContract();

        vm.prank(expert);
        escrow.deliverMilestone();

        vm.prank(pyme);
        escrow.rejectMilestone();

        vm.prank(expert);
        escrow.deliverMilestone();

        EscrowInterface.Milestone memory milestone = escrow.getMilestone(1);
        assertEq(uint256(milestone.status), uint256(EscrowInterface.MilestoneStatus.Delivered), "Milestone should be delivered again");
    }

    // ============================================
    // CANCEL CONTRACT TESTS
    // ============================================

    function testCancelContract_Success() public {
        vm.startPrank(pyme);
        token.approve(address(escrow), TOTAL_AMOUNT);
        escrow.fund();

        uint256 pymeBalanceBefore = token.balanceOf(pyme);

        escrow.cancelContract();

        assertEq(uint256(escrow.status()), uint256(EscrowInterface.EscrowStatus.Cancelled), "Status should be Cancelled");
        assertEq(token.balanceOf(pyme), pymeBalanceBefore + TOTAL_AMOUNT, "Pyme should receive refund");
        assertEq(token.balanceOf(address(escrow)), 0, "Escrow balance should be 0");
        vm.stopPrank();
    }

    function testCancelContract_RevertIfNotPyme() public {
        vm.startPrank(pyme);
        token.approve(address(escrow), TOTAL_AMOUNT);
        escrow.fund();
        vm.stopPrank();

        vm.prank(expert);
        vm.expectRevert("Only pyme");
        escrow.cancelContract();
    }

    function testCancelContract_RevertIfNotFunded() public {
        vm.prank(pyme);
        vm.expectRevert("Cannot cancel");
        escrow.cancelContract();
    }

    function testCancelContract_RevertIfActive() public {
        _fundAndAcceptContract();

        vm.prank(pyme);
        vm.expectRevert("Cannot cancel");
        escrow.cancelContract();
    }

    // ============================================
    // TACIT APPROVAL TESTS
    // ============================================

    function testCheckTacitApproval_Success() public {
        _fundAndAcceptContract();

        vm.prank(expert);
        escrow.deliverMilestone();

        vm.warp(block.timestamp + REVISION_PERIOD + 1);

        uint256 expertBalanceBefore = token.balanceOf(expert);
        uint256 milestone1Amount = milestoneAmounts[1];
        uint256 netPayment = _calculateNetPayment(milestone1Amount);

        escrow.checkTacitApproval();

        assertEq(token.balanceOf(expert), expertBalanceBefore + netPayment, "Expert should receive payment");

        EscrowInterface.Milestone memory milestone = escrow.getMilestone(1);
        assertEq(uint256(milestone.status), uint256(EscrowInterface.MilestoneStatus.Approved), "Milestone should be approved");
    }

    function testCheckTacitApproval_RevertIfPeriodNotExpired() public {
        _fundAndAcceptContract();

        vm.prank(expert);
        escrow.deliverMilestone();

        vm.warp(block.timestamp + REVISION_PERIOD - 1);

        vm.expectRevert("Revision period not expired");
        escrow.checkTacitApproval();
    }

    function testCheckTacitApproval_RevertIfNotDelivered() public {
        _fundAndAcceptContract();

        vm.warp(block.timestamp + REVISION_PERIOD + 1);

        vm.expectRevert("Not delivered");
        escrow.checkTacitApproval();
    }

    // ============================================
    // HELPER FUNCTIONS
    // ============================================

    function _fundAndAcceptContract() internal {
        vm.startPrank(pyme);
        token.approve(address(escrow), TOTAL_AMOUNT);
        escrow.fund();
        vm.stopPrank();

        vm.prank(expert);
        escrow.acceptContract();
    }
}
