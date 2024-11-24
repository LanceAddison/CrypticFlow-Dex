// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "@solmate/contracts/tokens/ERC20.sol";
import {UQ112x112} from "./libraries/UQ112x112.sol";
import {ICrypticFlowPair} from "./interfaces/ICrypticFlowPair.sol";
import {ICrypticFlowFactory} from "./interfaces/ICrypticFlowFactory.sol";
import {ICrypticFlowCallee} from "./interfaces/ICrypticFlowCallee.sol";

interface IERC20 {
    function balanceOf(address) external returns (uint256);
}

contract CrypticFlowPair is ERC20, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CrypticFlowPair__InsufficientLiquidityMinted();
    error CrypticFlowPair__InsufficientLiquidityBurned();
    error CrypticFlowPair__TransferFailed();
    error CrypticFlowPair__InsufficientOutputAmount();
    error CrypticFlowPair__InsufficientInputAmount();
    error CrypticFlowPair__InsufficientLiquidity();
    error CrypticFlowPair__InvalidK();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    using UQ112x112 for uint224;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3; // 1000

    address public s_factory;
    address public s_token0;
    address public s_token1;

    uint112 private s_reserve0;
    uint112 private s_reserve1;
    uint32 private blockTimestampLast;

    uint256 public s_price0CumulativeLast;
    uint256 public s_price1CumulativeLast;
    uint256 public kLast;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(address indexed sender, uint256 amount0Out, uint256 amount1Out, address indexed to);
    event Sync(uint256 reserve0, uint256 reserve1);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor() ERC20("CrypticFlow", "FLOW", 18) {
        s_factory = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function initializePair(address token0, address token1) external {
        s_token0 = token0;
        s_token1 = token1;
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint112 reserve0, uint112 reserve1) = getReserves();
        uint256 balance0 = IERC20(s_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(s_token1).balanceOf(address(this));
        uint256 amount0 = balance0 - s_reserve0;
        uint256 amount1 = balance1 - s_reserve1;

        bool feeOn = _mintFee(reserve0, reserve1);
        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(((totalSupply * amount0) / s_reserve0), ((totalSupply * amount1) / s_reserve1));
        }

        if (liquidity <= 0) revert CrypticFlowPair__InsufficientLiquidityMinted();
        _mint(to, liquidity);

        _update(balance0, balance1, reserve0, reserve1);
        if (feeOn) kLast = uint256(s_reserve0) * s_reserve1;
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint112 reserve0, uint112 reserve1) = getReserves();
        uint256 balance0 = IERC20(s_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(s_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(reserve0, reserve1);
        amount0 = (liquidity * balance0) / totalSupply;
        amount1 = (liquidity * balance1) / totalSupply;

        if (amount0 == 0 && amount1 == 0) revert CrypticFlowPair__InsufficientLiquidityBurned();
        _burn(address(this), liquidity);

        _safeTransfer(s_token0, to, amount0);
        _safeTransfer(s_token1, to, amount1);

        balance0 = IERC20(s_token0).balanceOf(address(this));
        balance1 = IERC20(s_token1).balanceOf(address(this));

        _update(balance0, balance1, reserve0, reserve1);
        if (feeOn) kLast = uint256(s_reserve0) * s_reserve1;
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external nonReentrant {
        if (amount0Out == 0 && amount1Out == 0) revert CrypticFlowPair__InsufficientOutputAmount();

        (uint112 reserve0, uint112 reserve1) = getReserves();

        if (amount0Out > reserve0 || amount1Out > reserve1) revert CrypticFlowPair__InsufficientLiquidity();

        if (amount0Out > 0) _safeTransfer(s_token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(s_token1, to, amount1Out);
        if (data.length > 0) ICrypticFlowCallee(to).crypticFlowCall(msg.sender, amount0Out, amount1Out, data);

        uint256 balance0 = IERC20(s_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(s_token1).balanceOf(address(this));

        uint256 amount0In = balance0 > reserve0 - amount0Out ? balance0 - (reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > reserve1 - amount1Out ? balance1 - (reserve1 - amount1Out) : 0;

        if (amount0In == 0 && amount1In == 0) revert CrypticFlowPair__InsufficientInputAmount();

        uint256 balance0Adjusted = (balance0 * 1000) - (amount0In * 3);
        uint256 balance1Adjusted = (balance1 * 1000) - (amount1In * 3);

        if (balance0Adjusted * balance1Adjusted < uint256(reserve0) * uint256(reserve1) * (1000 ** 2)) {
            revert CrypticFlowPair__InvalidK();
        }

        _update(balance0, balance1, reserve0, reserve1);
        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }

    function skim(address to) external nonReentrant {
        _safeTransfer(s_token0, to, IERC20(s_token0).balanceOf(address(this)) - s_reserve0);
        _safeTransfer(s_token1, to, IERC20(s_token1).balanceOf(address(this)) - s_reserve1);
    }

    function sync() external nonReentrant {
        _update(
            IERC20(s_token0).balanceOf(address(this)), IERC20(s_token1).balanceOf(address(this)), s_reserve0, s_reserve1
        );
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _update(uint256 _balance0, uint256 _balance1, uint112 _reserve0, uint112 _reserve1) private {
        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - blockTimestampLast;

            if (timeElapsed > 0 && _reserve0 > 0 && _reserve1 > 0) {
                s_price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                s_price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }

        s_reserve0 = uint112(_balance0);
        s_reserve1 = uint112(_balance1);
        blockTimestampLast = uint32(block.timestamp);

        emit Sync(s_reserve0, s_reserve1);
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = ICrypticFlowFactory(s_factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply * (rootK - rootKLast);
                    uint256 denominator = (rootK * 5) + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success,) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, value));
        if (!success) revert CrypticFlowPair__TransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                         PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getReserves() public view returns (uint112, uint112) {
        return (s_reserve0, s_reserve1);
    }
}
