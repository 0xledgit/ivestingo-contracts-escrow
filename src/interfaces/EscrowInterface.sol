// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface EscrowInterface {
    enum MilestoneStatus {
        InProgress,
        Delivered,
        Approved
    }

    enum EscrowStatus {
        Created,
        Funded,
        Active,
        Completed,
        Cancelled
    }

    struct Milestone {
        string description;
        uint256 amount;
        MilestoneStatus status;
        uint256 deliveryTimestamp;
    }

    event EscrowCreated(address indexed pyme, address indexed expert, uint256 totalAmount);
    event EscrowFunded(address indexed pyme, uint256 amount);
    event EscrowActivated(address indexed expert, uint256 advancePayment, uint256 platformFee);
    event MilestoneDelivered(uint256 indexed milestoneId, uint256 timestamp);
    event MilestoneApproved(uint256 indexed milestoneId, uint256 amount, bool tacit);
    event MilestoneRejected(uint256 indexed milestoneId);
    event PaymentReleased(address indexed expert, uint256 amount);
    event EscrowCompleted();
    event EscrowCancelled(address indexed pyme, uint256 refundAmount);

    function initialize(
        address _addressPyme,
        address _addressBaseToken,
        address _addressExpert,
        uint256 _totalMilestonesAmount,
        string[] memory _milestoneDescriptions,
        uint256[] memory _milestoneAmounts,
        uint256 _revisionPeriod,
        uint256 _platformFee
    ) external;

    function acceptContract() external;
    function deliverMilestone() external;
    function approveMilestone() external;
    function checkTacitApproval() external;
    function rejectMilestone() external;
    function cancelContract() external;
    function getMilestone(uint256 milestoneId) external view returns (Milestone memory);
    function getEscrowStatus() external view returns (EscrowStatus);
}
