// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@solmate/contracts/tokens/ERC20.sol";

contract ERC20MintableTransferFailed is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_, 18) {}

    function mint(uint256 amount, address to) public {
        _mint(to, amount);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert("Failed Transfer");
    }
}