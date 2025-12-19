// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MaritimeCarbonRegistry} from "../src/MaritimeCarbonRegistry.sol";

contract DeployMaritimeCarbonRegistry is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);
        MaritimeCarbonRegistry registry = new MaritimeCarbonRegistry();
        vm.stopBroadcast();

        console.log("MaritimeCarbonRegistry deployed at:", address(registry));
    }
}



//   MaritimeCarbonRegistry deployed at: 0x5FbDB2315678afecb367f032d93F642f64180aa3

//   MaritimeCarbonRegistry deployed at: 0x5FbDB2315678afecb367f032d93F642f64180aa3

// forge script script/DeployMaritimeCarbonRegistry.s.sol \
//   --rpc-url http://127.0.0.1:8545 \
//   --broadcast
