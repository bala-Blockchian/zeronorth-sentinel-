// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {MaritimeCarbonRegistry, MessageHashUtils} from "../src/MaritimeCarbonRegistry.sol";

contract MaritimeCarbonRegistryTest is Test {
    MaritimeCarbonRegistry registry;

    Vm.Wallet ownerWallet;
    address owner;
    uint256 ownerPrivateKey;

    string vesselName = "Chennai Express";
    uint256 co2Emissions = 3114;
    string grade = "B";

    function setUp() public {
        ownerWallet = vm.createWallet("OWNER");

        owner = ownerWallet.addr;
        ownerPrivateKey = ownerWallet.privateKey;
        vm.label(owner, "Owner");

        vm.prank(owner);
        registry = new MaritimeCarbonRegistry();
    }

    function testRecoverSignerAndUpdate() public {
        bytes32 messageHash = keccak256(abi.encodePacked(vesselName, co2Emissions, grade));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        registry.updateVesselGrade(vesselName, co2Emissions, grade, signature);
        (uint256 storedCO2, string memory storedGrade, uint256 timestamp) = registry.getVesselReport(vesselName);

        assertEq(storedCO2, co2Emissions);
        assertEq(storedGrade, grade);
        assertEq(timestamp, block.timestamp);
    }

    function testVerifySignatureReturnsTrue() public {
        bytes32 messageHash = keccak256(abi.encodePacked(vesselName, co2Emissions, grade));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bool isValid = registry.verifySignature(vesselName, co2Emissions, grade, signature);
        assertTrue(isValid);
    }
}
