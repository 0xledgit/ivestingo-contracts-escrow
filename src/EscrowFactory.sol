// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Escrow.sol";

contract EscrowFactory {
    address public admin;
    address public immutable escrowImplementation;

    address[] public escrows;
    mapping(address => address[]) public pymeEscrows;
    mapping(address => address[]) public expertEscrows;

    event EscrowDeployed(
        address indexed escrowAddress,
        address indexed pyme,
        address indexed expert,
        uint256 totalAmount
    );

    constructor() {
        admin = msg.sender;
        escrowImplementation = address(new Escrow());
    }

    function deployEscrow(
        address _addressPyme,
        address _addressBaseToken,
        address _addressExpert,
        uint256 _totalMilestonesAmount,
        string[] memory _milestoneDescriptions,
        uint256[] memory _milestoneAmounts,
        uint256 _revisionPeriod,
        uint256 _platformFee
    ) external returns (address) {
        address clone = Clones.clone(escrowImplementation);

        Escrow(clone).initialize(
            _addressPyme,
            _addressBaseToken,
            _addressExpert,
            _totalMilestonesAmount,
            _milestoneDescriptions,
            _milestoneAmounts,
            _revisionPeriod,
            _platformFee
        );

        escrows.push(clone);
        pymeEscrows[_addressPyme].push(clone);
        expertEscrows[_addressExpert].push(clone);

        emit EscrowDeployed(clone, _addressPyme, _addressExpert, _totalMilestonesAmount);

        return clone;
    }

    function getEscrows() external view returns (address[] memory) {
        return escrows;
    }

    function getPymeEscrows(address _pyme) external view returns (address[] memory) {
        return pymeEscrows[_pyme];
    }

    function getExpertEscrows(address _expert) external view returns (address[] memory) {
        return expertEscrows[_expert];
    }

    function getTotalEscrows() external view returns (uint256) {
        return escrows.length;
    }
}