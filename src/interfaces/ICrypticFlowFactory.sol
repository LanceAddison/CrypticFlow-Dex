// SPDX-License-Identifer: MIT
pragma solidity ^0.8.25;

interface ICrypticFlowFactory {
    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address, address) external pure returns (address);

    function createPair(address, address) external returns (address);

    function getAllPairsLength() external view returns (uint256);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}
