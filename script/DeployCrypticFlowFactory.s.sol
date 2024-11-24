// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {CrypticFlowFactory} from "../src/CrypticFlowFactory.sol";

contract DeployCrypticFlowFactory is Script {
    // change this address if your not deploying to anvil
    address feeToAddress = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;

    function run() external returns (CrypticFlowFactory) {
        vm.startBroadcast();
        CrypticFlowFactory factory = new CrypticFlowFactory(feeToAddress);
        vm.stopBroadcast();

        return factory;
    }
}
