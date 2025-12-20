// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test, Vm, console} from "forge-std/Test.sol";
import {DeploySEua} from "../../script/DeploySEua.s.sol";
import {sEUA} from "../../src/sEUA.sol";
import {MaritimeCarbonRegistry} from "../../src/MaritimeCarbonRegistry.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract sEUATest is Test {
    using MessageHashUtils for bytes32;

    DeploySEua public deployer;
    sEUA public seua;
    MaritimeCarbonRegistry public registry;

    Vm.Wallet public adminWallet;
    Vm.Wallet public vesselWallet;

    uint256 constant STARTING_ETH_BALANCE = 100e18;
    uint256 constant EUA_PRICE = 80e8;
    string constant VESSEL_NAME = "Evergreen_01";

    function setUp() public {
        adminWallet = vm.createWallet("admin");
        vesselWallet = vm.createWallet("vessel");
        console.log(adminWallet.privateKey);

        deployer = new DeploySEua();
        (seua, registry,) = deployer.run();
        vm.stopPrank();

        vm.deal(vesselWallet.addr, STARTING_ETH_BALANCE);
    }

    function testRegistryOwnerIsAdmin() public view {
        assertEq(registry.owner(), adminWallet.addr);
    }

    function testRegisterVesselAndCheckMapping() public {
        vm.prank(adminWallet.addr);
        registry.registerVessel(VESSEL_NAME, vesselWallet.addr);

        address registeredOwner = registry.vesselToOwner(VESSEL_NAME);
        assertEq(registeredOwner, vesselWallet.addr);
    }

    function testUpdateVesselGradeWithSignature() public {
        uint256 co2Emissions = 500e18;
        string memory grade = "B";

        vm.prank(adminWallet.addr);
        registry.registerVessel(VESSEL_NAME, vesselWallet.addr);

        address registeredOwner = registry.vesselToOwner(VESSEL_NAME);
        assertEq(registeredOwner, vesselWallet.addr);

        bytes32 messageHash = keccak256(abi.encodePacked(VESSEL_NAME, co2Emissions, grade));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminWallet.privateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(vesselWallet.addr);
        registry.updateVesselGrade(VESSEL_NAME, co2Emissions, grade, signature);

        (uint256 reportCo2, string memory reportGrade, uint256 timestamp, uint256 totalPaid) =
            registry.getVesselReport(VESSEL_NAME);

        assertEq(reportCo2, co2Emissions);
        assertEq(reportGrade, grade);
        assertEq(totalPaid, 0);
        assertEq(timestamp, block.timestamp);

        console.log("Vessel Grade Updated Successfully to:", reportGrade);

        uint256 pendingAllowance = registry.getPendingAllowance(VESSEL_NAME);
        assertEq(pendingAllowance, co2Emissions);

        vm.prank(adminWallet.addr);
        seua.updateEuaPrice(EUA_PRICE);

        vm.startPrank(vesselWallet.addr);
        seua.depositAndmint{value: STARTING_ETH_BALANCE}(co2Emissions);

        uint256 vesselBalance = seua.balanceOf(vesselWallet.addr);
        assertEq(vesselBalance, co2Emissions);

        seua.approve(address(registry), co2Emissions);
        registry.payCarbonTax(VESSEL_NAME, co2Emissions);
        vm.stopPrank();

        uint256 remainingAllowance = registry.getPendingAllowance(VESSEL_NAME);
        assertEq(remainingAllowance, 0);

        (,,, uint256 totalPaidAfter) = registry.getVesselReport(VESSEL_NAME);
        assertEq(totalPaidAfter, co2Emissions);

        assertEq(seua.balanceOf(address(registry)), co2Emissions);

        console.log("Full Compliance Loop Completed: Reported, Minted, and Paid.");
    }
}
