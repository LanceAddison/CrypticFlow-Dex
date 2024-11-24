// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {CrypticFlowPair} from "./CrypticFlowPair.sol";
import {ICrypticFlowPair} from "./interfaces/ICrypticFlowPair.sol";

contract CrypticFlowFactory {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CrypticFlowFactory__TokensCantBeTheSame();
    error CrypticFlowFactory__TokenCantBeAddressZero();
    error CrypticFlowFactory__PairAlreadyExists();
    error CrypticFlowFactory__OnlyFeeToSetterIsPermitted();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    address public feeTo;
    address public feeToSetter;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 totalPairs);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        if (tokenA == tokenB) revert CrypticFlowFactory__TokensCantBeTheSame();
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert CrypticFlowFactory__TokenCantBeAddressZero();
        if (getPair[token0][token1] != address(0)) revert CrypticFlowFactory__PairAlreadyExists();
        bytes memory bytecode = type(CrypticFlowPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ICrypticFlowPair(pair).initializePair(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        if (msg.sender != feeToSetter) revert CrypticFlowFactory__OnlyFeeToSetterIsPermitted();
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        if (msg.sender != feeToSetter) revert CrypticFlowFactory__OnlyFeeToSetterIsPermitted();
        feeToSetter = _feeToSetter;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getAllPairsLength() external view returns (uint256) {
        return allPairs.length;
    }
}
