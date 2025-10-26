// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./interfaces/EscrowInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Escrow is EscrowInterface {
    EscrowStatus public status;

    address public addressPyme;
    address public addressBaseToken;
    address public addressExpert;
    address public addressAdmin;

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

    constructor() {}

function initialize(
    address _addressPyme,
    address _addressBaseToken,
    address _addressExpert,
    uint256 _totalMilestonesAmount,
    string[] memory _milestoneDescriptions,
    uint256[] memory _milestoneAmounts,
    uint256 _revisionPeriod,
    uint256 _platformFee
) public {
    require(!initialized, "Already initialized");
    require(_addressPyme != address(0), "Invalid pyme address");
    require(_addressExpert != address(0), "Invalid expert address");
    require(_addressBaseToken != address(0), "Invalid token address");
    require(_milestoneDescriptions.length == _milestoneAmounts.length, "Mismatched arrays");
    require(_milestoneDescriptions.length > 0, "No milestones");
    require(_platformFee <= 10000, "Fee too high");

    addressPyme = _addressPyme;
    addressBaseToken = _addressBaseToken;
    addressExpert = _addressExpert;
    addressAdmin = msg.sender;
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

    bool success = IERC20(_addressBaseToken).transferFrom(_addressPyme, address(this), _totalMilestonesAmount);
    require(success, "Transfer failed");

    status = EscrowStatus.Funded;
    emit EscrowFunded(_addressPyme, _totalMilestonesAmount);
}

function acceptContract() public {
    require(msg.sender == addressExpert, "Only expert");
    require(status == EscrowStatus.Funded, "Not funded");
    require(totalMilestones > 0, "No milestones");

    uint256 totalPlatformFee = (totalMilestonesAmount * platformFee) / 10000;

    bool feeTransfer = IERC20(addressBaseToken).transfer(addressAdmin, totalPlatformFee);
    require(feeTransfer, "Fee transfer failed");

    uint256 milestone0Amount = milestoneAmounts[0];
    uint256 proportionalFee = (milestone0Amount * platformFee) / 10000;
    uint256 netPayment = milestone0Amount - proportionalFee;

    bool advanceTransfer = IERC20(addressBaseToken).transfer(addressExpert, netPayment);
    require(advanceTransfer, "Advance transfer failed");

    milestoneStatuses[0] = MilestoneStatus.Approved;

    if (totalMilestones > 1) {
        currentMilestone = 1;
    } else {
        status = EscrowStatus.Completed;
        emit EscrowCompleted();
    }

    if (status != EscrowStatus.Completed) {
        status = EscrowStatus.Active;
    }

    emit EscrowActivated(addressExpert, netPayment, totalPlatformFee);
    emit PaymentReleased(addressExpert, netPayment);
    emit MilestoneApproved(0, netPayment, false);
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

function approveMilestone() public {
    require(msg.sender == addressPyme, "Only pyme");
    require(status == EscrowStatus.Active, "Not active");
    require(currentMilestone < totalMilestones, "All milestones completed");
    require(milestoneStatuses[currentMilestone] == MilestoneStatus.Delivered, "Not delivered");

    _releaseMilestonePayment(currentMilestone, false);
}

function checkTacitApproval() public {
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

    bool success = IERC20(addressBaseToken).transfer(addressExpert, netPayment);
    require(success, "Payment transfer failed");

    milestoneStatuses[milestoneId] = MilestoneStatus.Approved;

    emit MilestoneApproved(milestoneId, netPayment, isTacit);
    emit PaymentReleased(addressExpert, netPayment);

    if (currentMilestone == totalMilestones - 1) {
        status = EscrowStatus.Completed;
        emit EscrowCompleted();
    } else {
        currentMilestone++;
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

function cancelContract() public {
    require(msg.sender == addressPyme, "Only pyme");
    require(status == EscrowStatus.Funded, "Cannot cancel");

    uint256 refundAmount = totalMilestonesAmount;

    bool success = IERC20(addressBaseToken).transfer(addressPyme, refundAmount);
    require(success, "Refund failed");

    status = EscrowStatus.Cancelled;
    emit EscrowCancelled(addressPyme, refundAmount);
}

}