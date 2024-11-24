// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ICrypticFlowPair} from "./interfaces/ICrypticFlowPair.sol";
import {ICrypticFlowFactory} from "./interfaces/ICrypticFlowFactory.sol";
import {CrypticFlowLibrary} from "./libraries/CrypticFlowLibrary.sol";

contract CrypticFlowRouter {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CrypticFlowRouter__AmountBInsufficient();
    error CrypticFlowRouter__AmountAInsufficient();
    error CrypticFlowRouter__SafeTransferFailed();
    error CrypticFlowRouter__AmountOutInsufficient();
    error CrypticFlowRouter__ExcessiveInputAmount();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    ICrypticFlowFactory factory;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address factoryAddress) {
        factory = ICrypticFlowFactory(factoryAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (factory.getPair(tokenA, tokenB) == address(0)) {
            factory.createPair(tokenA, tokenB);
        }

        (amountA, amountB) = _calculateLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);

        address pairAddress = CrypticFlowLibrary._pairFor(address(factory), tokenA, tokenB);
        _safeTransferFrom(tokenA, msg.sender, pairAddress, amountA);
        _safeTransferFrom(tokenB, msg.sender, pairAddress, amountB);
        liquidity = ICrypticFlowPair(pairAddress).mint(to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) public returns (uint256 amountA, uint256 amountB) {
        address pair = CrypticFlowLibrary._pairFor(address(factory), tokenA, tokenB);
        ICrypticFlowPair(pair).transferFrom(msg.sender, pair, liquidity);
        (amountA, amountB) = ICrypticFlowPair(pair).burn(to);
        if (amountA < amountAMin) revert CrypticFlowRouter__AmountAInsufficient();
        if (amountB < amountBMin) revert CrypticFlowRouter__AmountBInsufficient();
    }

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to)
        public
        returns (uint256[] memory amounts)
    {
        amounts = CrypticFlowLibrary.getAmountsOut(address(factory), amountIn, path);
        if (amounts[path.length - 1] < amountOutMin) revert CrypticFlowRouter__AmountOutInsufficient();
        _safeTransferFrom(
            path[0], msg.sender, CrypticFlowLibrary._pairFor(address(factory), path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to)
        public
        returns (uint256[] memory amounts)
    {
        amounts = CrypticFlowLibrary.getAmountsIn(address(factory), amountOut, path);
        if (amounts[path.length - 1] > amountInMax) revert CrypticFlowRouter__ExcessiveInputAmount();
        _safeTransferFrom(
            path[0], msg.sender, CrypticFlowLibrary._pairFor(address(factory), path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    /*//////////////////////////////////////////////////////////////
                     INTERNAL AND PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _calculateLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        (uint256 reserveA, uint256 reserveB) = CrypticFlowLibrary.getReserves(address(factory), _tokenA, _tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (_amountADesired, _amountBDesired);
        } else {
            uint256 amountBOptimal = CrypticFlowLibrary.quote(_amountADesired, reserveA, reserveB);
            if (amountBOptimal <= _amountBDesired) {
                if (amountBOptimal <= _amountBMin) revert CrypticFlowRouter__AmountBInsufficient();
                (amountA, amountB) = (_amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = CrypticFlowLibrary.quote(_amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= _amountADesired);
                if (amountAOptimal <= _amountAMin) revert CrypticFlowRouter__AmountAInsufficient();
                (amountA, amountB) = (amountAOptimal, _amountBDesired);
            }
        }
    }

    function _swap(uint256[] memory _amounts, address[] memory _path, address _to) internal {
        for (uint256 i; i < _path.length - 1; i++) {
            (address input, address output) = (_path[i], _path[i + 1]);
            (address token0,) = CrypticFlowLibrary._sortTokens(input, output);
            uint256 amountOut = _amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to =
                i < _path.length - 2 ? CrypticFlowLibrary._pairFor(address(factory), output, _path[i + 2]) : _to;

            ICrypticFlowPair(CrypticFlowLibrary._pairFor(address(factory), input, output)).swap(
                amount0Out, amount1Out, to, ""
            );
        }
    }

    function _safeTransferFrom(address _token, address _from, address _to, uint256 _value) private {
        (bool success,) =
            _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", _from, _to, _value));
        if (!success) revert CrypticFlowRouter__SafeTransferFailed();
    }
}
