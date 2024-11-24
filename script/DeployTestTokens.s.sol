// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {ERC20Mintable} from "../test/mocks/ERC20Mintable.sol";

contract DeployTestTokens is Script {
    address defaultAnvilAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external returns (ERC20Mintable, ERC20Mintable) {
        vm.startBroadcast();
        ERC20Mintable token1 = new ERC20Mintable("Token1", "TKN1");
        ERC20Mintable token2 = new ERC20Mintable("Token2", "TKN2");

        token1.mint(100 ether, defaultAnvilAddress);
        token2.mint(100000 ether, defaultAnvilAddress);
        vm.stopBroadcast();

        return (token1, token2);
    }
}