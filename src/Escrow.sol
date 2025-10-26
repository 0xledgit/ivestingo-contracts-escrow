// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./interfaces/EscrowInterface.sol";

contract Escrow is EscrowInterface {
EscrowStatus status;

address public addressPyme;
address public addressBaseToken;
address public addressExpert;

uint256 public totalMilestonesAmount;
mapping(uint256 => string) public milestoneDescriptions;
mapping(uint256 => uint256) public milestoneAmounts;
mapping(uint256 => MilestoneStatus) public milestoneStatuses;

uint256 public revisionPeriod;

uint256 platformFee;

constructor(){}

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
    addressPyme = _addressPyme;
    addressBaseToken = _addressBaseToken;
    addressExpert = _addressExpert;
    totalMilestonesAmount = _totalMilestonesAmount;
    revisionPeriod = _revisionPeriod;
    platformFee = _platformFee;

    for (uint256 i = 0; i < _milestoneDescriptions.length; i++) {
        milestoneDescriptions[i] = _milestoneDescriptions[i];
        milestoneAmounts[i] = _milestoneAmounts[i];
        milestoneStatuses[i] = MilestoneStatus.InProgress;
    }

    status = EscrowStatus.Active;
}

function getMilestone(uint256 milestoneId) public view{}
function approveMilestone() public {}
function claimPayment() public {}
function rejectMilestone() public {}

}