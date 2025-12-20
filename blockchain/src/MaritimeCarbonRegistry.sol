// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MaritimeCarbonRegistry {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct VesselReport {
        uint256 co2Emissions;
        string grade;
        uint256 timestamp;
    }

    mapping(string => VesselReport) private fleetReports;
    address public owner;

    event VesselReportUpdated(string vesselName, uint256 co2Emissions, string grade, uint256 timestamp);

    constructor() {
        owner = msg.sender;
    }

    function _getMessageHash(string memory _name, uint256 _co2, string memory _grade) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_name, _co2, _grade));
    }

    function _getEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32) {
        return messageHash.toEthSignedMessageHash();
    }

    function _recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) internal pure returns (address) {
        return ethSignedMessageHash.recover(signature);
    }

    function updateVesselGrade(string memory _name, uint256 _co2, string memory _grade, bytes memory _signature)
        external
    {
        bytes32 messageHash = _getMessageHash(_name, _co2, _grade);
        bytes32 ethSignedMessageHash = _getEthSignedMessageHash(messageHash);

        address signer = _recoverSigner(ethSignedMessageHash, _signature);

        require(signer == owner, "Invalid signature");

        fleetReports[_name] = VesselReport({co2Emissions: _co2, grade: _grade, timestamp: block.timestamp});

        emit VesselReportUpdated(_name, _co2, _grade, block.timestamp);
    }

    function verifySignature(string memory _name, uint256 _co2, string memory _grade, bytes memory _signature)
        external
        view
        returns (bool)
    {
        bytes32 messageHash = _getMessageHash(_name, _co2, _grade);
        bytes32 ethSignedMessageHash = _getEthSignedMessageHash(messageHash);
        address signer = _recoverSigner(ethSignedMessageHash, _signature);

        return signer == owner;
    }

    function getVesselReport(string memory _name)
        external
        view
        returns (uint256 co2Emissions, string memory grade, uint256 timestamp)
    {
        VesselReport memory report = fleetReports[_name];
        return (report.co2Emissions, report.grade, report.timestamp);
    }
}
