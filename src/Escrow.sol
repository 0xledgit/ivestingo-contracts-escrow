// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./interfaces/EscrowInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Escrow is EscrowInterface, ReentrancyGuard {
    uint256 private constant ABSOLUTE_MAX_MILESTONES = 1000;

    EscrowStatus public status;

    address public addressPyme;
    address public addressBaseToken;
    address public addressExpert;
    address public addressAdmin;
    address public immutable factory;

    uint256 public totalMilestonesAmount;
    uint256 public totalMilestones;
    uint256 public currentMilestone;
    uint256 public revisionPeriod;
    uint256 public platformFee;

    mapping(uint256 => string) public milestoneDescriptions;
    mapping(uint256 => uint256) public milestoneAmounts;
    mapping(uint256 => MilestoneStatus) public milestoneStatuses;
    mapping(uint256 => uint256) public milestoneDeliveryTimestamps;

    bool private initialized;

    constructor() {
        factory = msg.sender;
    }

function initialize(
    address _addressPyme,
    address _addressBaseToken,
    address _addressExpert,
    address _addressAdmin,
    uint256 _totalMilestonesAmount,
    string[] memory _milestoneDescriptions,
    uint256[] memory _milestoneAmounts,
    uint256 _revisionPeriod,
    uint256 _platformFee
) public {
    require(msg.sender == factory, "Only factory can initialize");
    require(!initialized, "Already initialized");
    require(_addressPyme != address(0), "Invalid pyme address");
    require(_addressExpert != address(0), "Invalid expert address");
    require(_addressBaseToken != address(0), "Invalid token address");
    require(_addressAdmin != address(0), "Invalid admin address");
    require(_milestoneDescriptions.length == _milestoneAmounts.length, "Mismatched arrays");
    require(_milestoneDescriptions.length > 0, "No milestones");
    require(_milestoneDescriptions.length <= ABSOLUTE_MAX_MILESTONES, "Exceeds max milestones");
    require(_platformFee <= 10000, "Fee too high");

    addressPyme = _addressPyme;
    addressBaseToken = _addressBaseToken;
    addressExpert = _addressExpert;
    addressAdmin = _addressAdmin;
    totalMilestonesAmount = _totalMilestonesAmount;
    totalMilestones = _milestoneDescriptions.length;
    revisionPeriod = _revisionPeriod;
    platformFee = _platformFee;
    currentMilestone = 0;

    uint256 totalCheck = 0;
    for (uint256 i = 0; i < _milestoneDescriptions.length; i++) {
        milestoneDescriptions[i] = _milestoneDescriptions[i];
        milestoneAmounts[i] = _milestoneAmounts[i];
        milestoneStatuses[i] = MilestoneStatus.InProgress;
        totalCheck += _milestoneAmounts[i];
    }

    require(totalCheck == _totalMilestonesAmount, "Amount mismatch");

    initialized = true;
    status = EscrowStatus.Created;

    emit EscrowCreated(_addressPyme, _addressExpert, _totalMilestonesAmount);
}

function fund() public nonReentrant {
    require(msg.sender == addressPyme, "Only pyme");
    require(status == EscrowStatus.Created, "Not in created state");

    bool success = IERC20(addressBaseToken).transferFrom(addressPyme, address(this), totalMilestonesAmount);
    require(success, "Transfer failed");

    status = EscrowStatus.Funded;
    emit EscrowFunded(addressPyme, totalMilestonesAmount);
}

function acceptContract() public nonReentrant {
    require(msg.sender == addressExpert, "Only expert");
    require(status == EscrowStatus.Funded, "Not funded");
    require(totalMilestones > 0, "No milestones");

    uint256 totalPlatformFee = (totalMilestonesAmount * platformFee) / 10000;
    uint256 milestone0Amount = milestoneAmounts[0];
    uint256 proportionalFee = (milestone0Amount * platformFee) / 10000;
    uint256 netPayment = milestone0Amount - proportionalFee;

    milestoneStatuses[0] = MilestoneStatus.Approved;

    if (totalMilestones > 1) {
        currentMilestone = 1;
        status = EscrowStatus.Active;
    } else {
        status = EscrowStatus.Completed;
    }

    bool feeTransfer = IERC20(addressBaseToken).transfer(addressAdmin, totalPlatformFee);
    require(feeTransfer, "Fee transfer failed");

    bool advanceTransfer = IERC20(addressBaseToken).transfer(addressExpert, netPayment);
    require(advanceTransfer, "Advance transfer failed");

    emit EscrowActivated(addressExpert, netPayment, totalPlatformFee);
    emit PaymentReleased(addressExpert, netPayment);
    emit MilestoneApproved(0, netPayment, false);

    if (status == EscrowStatus.Completed) {
        emit EscrowCompleted();
    }
}

function getMilestone(uint256 milestoneId) public view returns (Milestone memory) {
    require(milestoneId < totalMilestones, "Invalid milestone");
    return Milestone({
        description: milestoneDescriptions[milestoneId],
        amount: milestoneAmounts[milestoneId],
        status: milestoneStatuses[milestoneId],
        deliveryTimestamp: milestoneDeliveryTimestamps[milestoneId]
    });
}

function getEscrowStatus() public view returns (EscrowStatus) {
    return status;
}

function deliverMilestone() public {
    require(msg.sender == addressExpert, "Only expert");
    require(status == EscrowStatus.Active, "Not active");
    require(currentMilestone < totalMilestones, "All milestones completed");
    require(milestoneStatuses[currentMilestone] == MilestoneStatus.InProgress, "Milestone not in progress");

    milestoneStatuses[currentMilestone] = MilestoneStatus.Delivered;
    milestoneDeliveryTimestamps[currentMilestone] = block.timestamp;

    emit MilestoneDelivered(currentMilestone, block.timestamp);
}

function approveMilestone() public nonReentrant {
    require(msg.sender == addressPyme, "Only pyme");
    require(status == EscrowStatus.Active, "Not active");
    require(currentMilestone < totalMilestones, "All milestones completed");
    require(milestoneStatuses[currentMilestone] == MilestoneStatus.Delivered, "Not delivered");

    _releaseMilestonePayment(currentMilestone, false);
}

function checkTacitApproval() public nonReentrant {
    require(status == EscrowStatus.Active, "Not active");
    require(currentMilestone < totalMilestones, "All milestones completed");
    require(milestoneStatuses[currentMilestone] == MilestoneStatus.Delivered, "Not delivered");

    uint256 deliveryTime = milestoneDeliveryTimestamps[currentMilestone];
    require(deliveryTime > 0, "No delivery timestamp");
    require(block.timestamp >= deliveryTime + revisionPeriod, "Revision period not expired");

    _releaseMilestonePayment(currentMilestone, true);
}

function _releaseMilestonePayment(uint256 milestoneId, bool isTacit) private {
    uint256 milestoneAmount = milestoneAmounts[milestoneId];
    uint256 proportionalFee = (milestoneAmount * platformFee) / 10000;
    uint256 netPayment = milestoneAmount - proportionalFee;

    milestoneStatuses[milestoneId] = MilestoneStatus.Approved;

    if (currentMilestone == totalMilestones - 1) {
        status = EscrowStatus.Completed;
    } else {
        currentMilestone++;
    }

    bool success = IERC20(addressBaseToken).transfer(addressExpert, netPayment);
    require(success, "Payment transfer failed");

    emit MilestoneApproved(milestoneId, netPayment, isTacit);
    emit PaymentReleased(addressExpert, netPayment);

    if (status == EscrowStatus.Completed) {
        emit EscrowCompleted();
    }
}

function rejectMilestone() public {
    require(msg.sender == addressPyme, "Only pyme");
    require(status == EscrowStatus.Active, "Not active");
    require(currentMilestone < totalMilestones, "All milestones completed");
    require(milestoneStatuses[currentMilestone] == MilestoneStatus.Delivered, "Not delivered");

    milestoneStatuses[currentMilestone] = MilestoneStatus.InProgress;
    milestoneDeliveryTimestamps[currentMilestone] = 0;

    emit MilestoneRejected(currentMilestone);
}

function cancelContract() public nonReentrant {
    require(msg.sender == addressPyme, "Only pyme");
    require(status == EscrowStatus.Funded, "Cannot cancel");

    uint256 refundAmount = totalMilestonesAmount;

    status = EscrowStatus.Cancelled;

    bool success = IERC20(addressBaseToken).transfer(addressPyme, refundAmount);
    require(success, "Refund failed");

    emit EscrowCancelled(addressPyme, refundAmount);
}

}