// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../src/test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address ethUsdPriceFeed;
    }

    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_ETH_PRICE = 2000e8;

    constructor() {
        if (block.chainid == 31337) {
            activeNetworkConfig = _getOrCreateAnvilEthConfig();
        } else {
            activeNetworkConfig = NetworkConfig({ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306});
        }
    }

    function _getOrCreateAnvilEthConfig() internal returns (NetworkConfig memory) {
        if (activeNetworkConfig.ethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdFeedMock = new MockV3Aggregator(DECIMALS, INITIAL_ETH_PRICE);
        vm.stopBroadcast();

        return NetworkConfig({ethUsdPriceFeed: address(ethUsdFeedMock)});
    }
}
