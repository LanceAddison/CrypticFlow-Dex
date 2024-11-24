// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {CrypticFlowRouter} from "../../src/CrypticFlowRouter.sol";
import {CrypticFlowFactory} from "../../src/CrypticFlowFactory.sol";
import {CrypticFlowPair, ICrypticFlowPair} from "../../src/CrypticFlowPair.sol";
import {CrypticFlowLibrary} from "../../src/libraries/CrypticFlowLibrary.sol";
import {ERC20Mintable} from "../mocks/ERC20Mintable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract Handler is Test {
    CrypticFlowRouter router;
    CrypticFlowFactory factory;
    CrypticFlowPair public pair;

    address public BOB = makeAddr("bob");
    uint256 constant STARTING_WETH_BALANCE = 100 ether;
    uint256 constant STARTING_USDC_BALANCE = 1000000 ether;

    ERC20Mintable public weth;
    ERC20Mintable public usdc;

    uint256 public kLast;
    uint256 public kCurrent;

    uint256 public wethReserves;
    uint256 public usdcReserves;

    uint256 public wethBalance;
    uint256 public usdcBalance;

    constructor(CrypticFlowFactory _factory, CrypticFlowRouter _router) {
        factory = _factory;
        router = _router;

        weth = new ERC20Mintable("WETH", "WETH");
        usdc = new ERC20Mintable("USDC", "USDC");

        weth.mint(STARTING_WETH_BALANCE, BOB);
        usdc.mint(STARTING_USDC_BALANCE, BOB);

        vm.startPrank(BOB);
        weth.approve(address(router), 10 ether);
        usdc.approve(address(router), 20000 ether);
        router.addLiquidity(address(weth), address(usdc), 10 ether, 20000 ether, 10 ether, 20000 ether, BOB);
        vm.stopPrank();

        pair = CrypticFlowPair(factory.getPair(address(weth), address(usdc)));
    }

    function addLiquidity(uint256 amountWethDesired) public {
        uint256 bobWethBalanceAdjusted = weth.balanceOf(BOB) / 2;
        amountWethDesired = bound(amountWethDesired, 1, bobWethBalanceAdjusted);
        uint256 amountUsdcDesired = amountWethDesired * 2000;
        uint256 amountWethMin = (amountWethDesired * 99) / 100;
        uint256 amountUsdcMin = (amountUsdcDesired * 99) / 100;

        (wethReserves, usdcReserves) = CrypticFlowLibrary.getReserves(address(factory), address(weth), address(usdc));
        kLast = uint256(wethReserves) * usdcReserves;

        vm.startPrank(BOB);
        weth.approve(address(router), amountWethDesired);
        usdc.approve(address(router), amountUsdcDesired);
        router.addLiquidity(
            address(weth), address(usdc), amountWethDesired, amountUsdcDesired, amountWethMin, amountUsdcMin, BOB
        );
        vm.stopPrank();

        (wethReserves, usdcReserves) = CrypticFlowLibrary.getReserves(address(factory), address(weth), address(usdc));
        kCurrent = uint256(wethReserves) * usdcReserves;
        wethBalance = weth.balanceOf(address(pair));
        usdcBalance = usdc.balanceOf(address(pair));
    }

    function removeLiquidity(uint256 amountLiquidityToRemove) public {
        uint256 bobLpTokenBalance = pair.balanceOf(BOB);
        if (bobLpTokenBalance == 0) return;
        amountLiquidityToRemove = bound(amountLiquidityToRemove, 1, bobLpTokenBalance / 2);

        // reserves are flipped because the factory sorted the tokens during the initial creation
        (usdcReserves, wethReserves) = pair.getReserves();

        uint256 amountWethMin = (wethReserves * amountLiquidityToRemove / bobLpTokenBalance) * 99 / 100;
        uint256 amountUsdcMin = (usdcReserves * amountLiquidityToRemove / bobLpTokenBalance) * 99 / 100;

        vm.startPrank(BOB);
        CrypticFlowPair(pair).approve(address(router), amountLiquidityToRemove);
        router.removeLiquidity(address(usdc), address(weth), amountLiquidityToRemove, amountUsdcMin, amountWethMin, BOB);
        vm.stopPrank();

        (wethReserves, usdcReserves) = CrypticFlowLibrary.getReserves(address(factory), address(weth), address(usdc));
        wethBalance = weth.balanceOf(address(pair));
        usdcBalance = usdc.balanceOf(address(pair));
    }
}
