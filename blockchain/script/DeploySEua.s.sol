// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {sEUA} from "../src/sEUA.sol";
import {MaritimeCarbonRegistry} from "../src/MaritimeCarbonRegistry.sol";

contract DeploySEua is Script {
    function run() external returns (sEUA, MaritimeCarbonRegistry, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        address ethFeed = helperConfig.activeNetworkConfig();

        vm.startBroadcast(109570584058932911814882329213916337771104575516230068759881284754962024964824);
        sEUA seua = new sEUA(ethFeed);

        MaritimeCarbonRegistry registry = new MaritimeCarbonRegistry(address(seua));
        vm.stopBroadcast();

        return (seua, registry, helperConfig);
    }
}
