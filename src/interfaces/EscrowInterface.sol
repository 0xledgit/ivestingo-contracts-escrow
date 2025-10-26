// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface EscrowInterface {
    enum MilestoneStatus {
        Delivered,
        InProgress,
        Approved
    }
    enum EscrowStatus {
        Created,
        Active,
        Completed
    }

    struct Milestone {
        string description;
        uint256 amount;
        MilestoneStatus status;
    }

    function getMilestone(uint256 milestoneId) external view;
    function completeMilestone(uint256 milestoneId) external;
    function approveMilestone(uint256 milestoneId) external;
    function getEscrowStatus() external view returns (EscrowStatus);
}
