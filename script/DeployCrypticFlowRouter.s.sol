// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {CrypticFlowFactory} from "../src/CrypticFlowFactory.sol";
import {CrypticFlowRouter} from "../src/CrypticFlowRouter.sol";

contract DeployCrypticFlowRouter is Script {
    // change this address if your not deploying to anvil
    address feeToAddress = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;

    function run() external returns (CrypticFlowFactory, CrypticFlowRouter) {
        vm.startBroadcast();
        CrypticFlowFactory factory = new CrypticFlowFactory(feeToAddress);
        CrypticFlowRouter router = new CrypticFlowRouter(address(factory));
        vm.stopBroadcast();

        return (factory, router);
    }
}