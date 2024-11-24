// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {CrypticFlowPair, ICrypticFlowPair} from "../CrypticFlowPair.sol";
import {ICrypticFlowFactory} from "../interfaces/ICrypticFlowFactory.sol";

library CrypticFlowLibrary {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CrypticFlowLibrary__InsufficientAmount();
    error CrypticFlowLibrary__InsufficientLiquidity();
    error CrypticFlowLibrary__InvalidPath();

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getReserves(address factoryAddress, address tokenA, address tokenB)
        public
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1) = ICrypticFlowPair(_pairFor(factoryAddress, token0, token1)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /*//////////////////////////////////////////////////////////////
                         PUBLIC PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function quote(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        if (amountIn == 0) revert CrypticFlowLibrary__InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert CrypticFlowLibrary__InsufficientLiquidity();

        return (amountIn * reserveOut) / reserveIn;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        if (amountIn == 0) revert CrypticFlowLibrary__InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert CrypticFlowLibrary__InsufficientLiquidity();
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        if (amountOut == 0) revert CrypticFlowLibrary__InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert CrypticFlowLibrary__InsufficientLiquidity();
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;

        return (numerator / denominator) + 1;
    }

    function getAmountsOut(address factory, uint256 amountIn, address[] memory path)
        public
        returns (uint256[] memory)
    {
        if (path.length < 2) revert CrypticFlowLibrary__InvalidPath();
        uint256[] memory amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserve0, uint256 reserve1) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserve0, reserve1);
        }

        return amounts;
    }

    function getAmountsIn(address factory, uint256 amountOut, address[] memory path)
        public
        returns (uint256[] memory)
    {
        if (path.length < 2) revert CrypticFlowLibrary__InvalidPath();
        uint256[] memory amounts = new uint256[](path.length);
        amounts[path.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserve0, uint256 reserve1) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserve0, reserve1);
        }

        return amounts;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _pairFor(address _factoryAddress, address _tokenA, address _tokenB)
        internal
        pure
        returns (address pairAddress)
    {
        (address token0, address token1) = _sortTokens(_tokenA, _tokenB);
        pairAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            _factoryAddress,
                            keccak256(abi.encodePacked(token0, token1)),
                            keccak256(type(CrypticFlowPair).creationCode)
                        )
                    )
                )
            )
        );
    }

    function _sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0, address token1) {
        return _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
    }
}
