// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface ICrypticFlowPair {
    function totalSupply() external view returns (uint256);

    function balanceOf(address) external returns (uint256);

    function initializePair(address, address) external;

    function getReserves() external returns (uint112, uint112);

    function mint(address) external returns (uint256);

    function burn(address) external returns (uint256, uint256);

    function transferFrom(address, address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function swap(uint256, uint256, address, bytes calldata) external;
}