// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {CrypticFlowPair, UQ112x112} from "../../src/CrypticFlowPair.sol";
import {CrypticFlowFactory} from "../../src/CrypticFlowFactory.sol";
import {DeployCrypticFlowFactory} from "../../script/DeployCrypticFlowFactory.s.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20Mintable} from "../mocks/ERC20Mintable.sol";
import {ERC20MintableTransferFailed} from "../mocks/ERC20MintableTransferFailed.sol";
import {CrypticFlowLibrary} from "../../src/libraries/CrypticFlowLibrary.sol";

contract CrypticFlowPairTest is Test {
    CrypticFlowPair pair;
    CrypticFlowFactory factory;
    DeployCrypticFlowFactory deployer;

    ERC20Mintable private weth;
    ERC20Mintable private usdc;

    address public BOB = makeAddr("bob");
    address public ALICE = makeAddr("alice");
    address public FEES = makeAddr("feeTo");
    uint256 public constant STARTING_WETH_BALANCE = 100 ether;
    uint256 public constant STARTING_USDC_BALANCE = 1000000 ether;

    function setUp() public {
        deployer = new DeployCrypticFlowFactory();
        factory = deployer.run();

        weth = new ERC20Mintable("WETH", "WETH");
        usdc = new ERC20Mintable("USDC", "USDC");

        // Must do for _mintFee to work properly in the pair contract
        pair = CrypticFlowPair(factory.createPair(address(weth), address(usdc)));

        weth.mint(STARTING_WETH_BALANCE, BOB);
        usdc.mint(STARTING_USDC_BALANCE, BOB);
        weth.mint(STARTING_WETH_BALANCE, ALICE);
        usdc.mint(STARTING_USDC_BALANCE, ALICE);
    }

    modifier initialMint() {
        vm.warp(0);

        vm.startPrank(BOB);
        weth.transfer(address(pair), 10 ether);
        usdc.transfer(address(pair), 20000 ether);
        vm.stopPrank();

        pair.mint(BOB);
        _;
    }

    function calculateCumulativePrices() public view returns (uint256, uint256) {
        (uint112 reservesWeth, uint112 reservesUsdc) = pair.getReserves();

        uint256 initialPrice0 = (reservesUsdc * uint256(UQ112x112.Q112)) / reservesWeth;
        uint256 initialPrice1 = (reservesWeth * uint256(UQ112x112.Q112)) / reservesUsdc;

        return (initialPrice0, initialPrice1);
    }

    /*//////////////////////////////////////////////////////////////
                          MINT LIQUIDITY TESTS
    //////////////////////////////////////////////////////////////*/
    function testMint() public {
        vm.startPrank(BOB);
        weth.transfer(address(pair), 10 ether);
        usdc.transfer(address(pair), 20000 ether);
        vm.stopPrank();

        pair.mint(BOB);

        assertGt(pair.balanceOf(BOB), 0, "LP = 0");
    }

    function testMintWhenAlreadyLiquidity() public initialMint {
        vm.startPrank(BOB);
        weth.transfer(address(pair), 20 ether);
        usdc.transfer(address(pair), 40000 ether);
        vm.stopPrank();

        pair.mint(BOB);

        (uint112 reservesWeth, uint112 reservesUsdc) = pair.getReserves();

        uint256 expectedReservesWeth = 30 ether;
        uint256 expectedReservesUsdc = 60000 ether;

        assertEq(pair.balanceOf(BOB), pair.totalSupply() - 1000);
        assertEq(reservesWeth, expectedReservesWeth);
        assertEq(reservesUsdc, expectedReservesUsdc);
    }

    function testMintUnbalanced() public initialMint {
        vm.startPrank(BOB);
        weth.transfer(address(pair), 10 ether);
        usdc.transfer(address(pair), 10000 ether);
        vm.stopPrank();

        pair.mint(BOB);

        (uint112 reservesWeth, uint112 reservesUsdc) = pair.getReserves();

        uint256 expectedReservesWeth = 20 ether;
        uint256 expectedReservesUsdc = 30000 ether;

        assertEq(pair.balanceOf(BOB), pair.totalSupply() - 1000);
        assertEq(reservesWeth, expectedReservesWeth);
        assertEq(reservesUsdc, expectedReservesUsdc);
    }

    function testMintedInsufficientLiquidity() public {
        vm.startPrank(BOB);
        weth.transfer(address(pair), 1000);
        usdc.transfer(address(pair), 1000);
        vm.stopPrank();

        vm.expectRevert(CrypticFlowPair.CrypticFlowPair__InsufficientLiquidityMinted.selector);
        pair.mint(BOB);
    }

    function testMintedLiquidityUnderflow() public {
        vm.expectRevert(hex"4e487b710000000000000000000000000000000000000000000000000000000000000011");
        pair.mint(BOB);
    }

    /*//////////////////////////////////////////////////////////////
                          BURN LIQUIDITY TESTS
    //////////////////////////////////////////////////////////////*/
    function testBurn() public initialMint {
        uint256 bobLpBalance = pair.balanceOf(BOB);
        vm.prank(BOB);
        pair.transfer(address(pair), bobLpBalance);

        pair.burn(BOB);

        (uint112 wethMinLiquidity, uint112 usdcMinLiquidity) = pair.getReserves();

        uint256 expectedBobLpBalance = 0;
        uint256 expectedBobWethBalance = STARTING_WETH_BALANCE - wethMinLiquidity;
        uint256 expectedBobUsdcBalance = STARTING_USDC_BALANCE - usdcMinLiquidity;

        assertEq(pair.balanceOf(BOB), expectedBobLpBalance);
        assertEq(weth.balanceOf(BOB), expectedBobWethBalance);
        assertEq(usdc.balanceOf(BOB), expectedBobUsdcBalance);
    }

    function testBurnUnbalancedLiquidity() public initialMint {
        vm.startPrank(ALICE);
        weth.transfer(address(pair), 10 ether);
        usdc.transfer(address(pair), 10000 ether);
        vm.stopPrank();
        pair.mint(ALICE);

        assertEq(pair.balanceOf(ALICE), pair.totalSupply() - (pair.balanceOf(BOB) + 1000));

        uint256 aliceLpBalance = pair.balanceOf(ALICE);
        vm.prank(ALICE);
        pair.transfer(address(pair), aliceLpBalance);

        pair.burn(ALICE);

        (uint112 reservesWeth, uint112 reservesUsdc) = pair.getReserves();

        uint256 expectedAliceWethBalance = STARTING_WETH_BALANCE - (reservesWeth - 10 ether);
        uint256 expectedAliceUsdcBalance = STARTING_USDC_BALANCE - (reservesUsdc - 20000 ether);

        assertEq(pair.balanceOf(ALICE), 0);
        assertEq(weth.balanceOf(ALICE), expectedAliceWethBalance);
        assertEq(usdc.balanceOf(ALICE), expectedAliceUsdcBalance);

        uint256 bobLpBalance = pair.balanceOf(BOB);
        vm.prank(BOB);
        pair.transfer(address(pair), bobLpBalance);
        pair.burn(BOB);

        (uint112 wethMinLiquidity, uint112 usdcMinLiquidity) = pair.getReserves();

        uint256 expectedBobLpBalance = 0;
        uint256 expectedBobWethBalance = (STARTING_WETH_BALANCE + (reservesWeth - 10 ether)) - wethMinLiquidity;
        uint256 expectedBobUsdcBalance = (STARTING_USDC_BALANCE + (reservesUsdc - 20000 ether)) - usdcMinLiquidity;
        uint256 expectedLpTotalSupply = 1000;

        assertEq(pair.balanceOf(BOB), expectedBobLpBalance);
        assertEq(weth.balanceOf(BOB), expectedBobWethBalance);
        assertEq(usdc.balanceOf(BOB), expectedBobUsdcBalance);
        assertEq(pair.totalSupply(), expectedLpTotalSupply);
    }

    function testNotEnoughLiquidityBurned() public initialMint {
        vm.expectRevert(CrypticFlowPair.CrypticFlowPair__InsufficientLiquidityBurned.selector);
        pair.burn(BOB);
    }

    function testNotEnoughTotalSupply() public {
        vm.expectRevert(hex"4e487b710000000000000000000000000000000000000000000000000000000000000012");
        pair.burn(BOB);
    }

    /*//////////////////////////////////////////////////////////////
                               SWAP TESTS
    //////////////////////////////////////////////////////////////*/
    function testSwap() public initialMint {
        vm.prank(ALICE);
        weth.transfer(address(pair), 1 ether);

        uint256 usdcOut = CrypticFlowLibrary.getAmountOut(1 ether, 10 ether, 20000 ether);

        pair.swap(0, usdcOut, ALICE, "");

        (uint112 reservesWeth, uint112 reservesUsdc) = pair.getReserves();

        uint256 expectedAliceWethBalance = STARTING_WETH_BALANCE - 1 ether;
        uint256 expectedAliceUsdcBalance = STARTING_USDC_BALANCE + usdcOut;
        uint256 expectedReservesWeth = 11 ether;
        uint256 expectedReservesUsdc = 20000 ether - usdcOut;

        assertEq(weth.balanceOf(ALICE), expectedAliceWethBalance);
        assertEq(usdc.balanceOf(ALICE), expectedAliceUsdcBalance);
        assertEq(reservesWeth, expectedReservesWeth);
        assertEq(reservesUsdc, expectedReservesUsdc);
    }

    function testSwapReversed() public initialMint {
        vm.prank(ALICE);
        usdc.transfer(address(pair), 2000 ether);

        uint256 wethOut = CrypticFlowLibrary.getAmountOut(2000 ether, 20000 ether, 10 ether);

        pair.swap(wethOut, 0, ALICE, "");

        (uint112 reservesWeth, uint112 reservesUsdc) = pair.getReserves();

        uint256 expectedAliceWethBalance = STARTING_WETH_BALANCE + wethOut;
        uint256 expectedAliceUsdcBalance = STARTING_USDC_BALANCE - 2000 ether;
        uint256 expectedReservesWeth = 10 ether - wethOut;
        uint256 expectedReservesUsdc = 22000 ether;

        assertEq(weth.balanceOf(ALICE), expectedAliceWethBalance);
        assertEq(usdc.balanceOf(ALICE), expectedAliceUsdcBalance);
        assertEq(reservesWeth, expectedReservesWeth);
        assertEq(reservesUsdc, expectedReservesUsdc);
    }

    function testSwapBidirectional() public initialMint {
        vm.startPrank(ALICE);
        weth.transfer(address(pair), 1 ether);
        usdc.transfer(address(pair), 2000 ether);

        uint256 wethOut = 0.909 ether;
        uint256 usdcOut = 1818 ether;
        pair.swap(wethOut, usdcOut, ALICE, "");

        (uint112 reservesWeth, uint112 reservesUsdc) = pair.getReserves();

        uint256 expectedAliceWethBalance = STARTING_WETH_BALANCE - (1 ether - wethOut);
        uint256 expectedAliceUsdcBalance = STARTING_USDC_BALANCE - (2000 ether - usdcOut);
        uint256 expectedReservesWeth = 10 ether + (1 ether - wethOut);
        uint256 expectedReservesUsdc = 20000 ether + (2000 ether - usdcOut);

        assertEq(weth.balanceOf(ALICE), expectedAliceWethBalance);
        assertEq(usdc.balanceOf(ALICE), expectedAliceUsdcBalance);
        assertEq(reservesWeth, expectedReservesWeth);
        assertEq(reservesUsdc, expectedReservesUsdc);
    }

    function testSwapUnderpriced() public initialMint {
        vm.prank(ALICE);
        weth.transfer(address(pair), 1 ether);

        uint256 usdcOut = 1800 ether;
        pair.swap(0, usdcOut, ALICE, "");

        uint256 expectedAliceBalanceUsdc = STARTING_USDC_BALANCE + 1800 ether;

        assertEq(usdc.balanceOf(ALICE), expectedAliceBalanceUsdc, "unexpected token balance");
    }

    function testSwapOverpriced() public initialMint {
        vm.prank(ALICE);
        usdc.transfer(address(pair), 2000 ether);

        uint256 wethOut = 1 ether;
        vm.expectRevert(CrypticFlowPair.CrypticFlowPair__InvalidK.selector);
        pair.swap(wethOut, 0, ALICE, "");
    }

    function testOutputAmountsAreZero() public {
        vm.expectRevert(CrypticFlowPair.CrypticFlowPair__InsufficientOutputAmount.selector);
        pair.swap(0, 0, BOB, "");
    }

    function testInputAmountsAreZero() public initialMint {
        vm.expectRevert(CrypticFlowPair.CrypticFlowPair__InsufficientInputAmount.selector);
        pair.swap(0, 2000 ether, ALICE, "");
    }

    function testCantSwapIfInsufficientLiquidity() public {
        vm.prank(ALICE);
        weth.transfer(address(pair), 1 ether);

        uint256 usdcOut = 1818 ether;
        vm.expectRevert(CrypticFlowPair.CrypticFlowPair__InsufficientLiquidity.selector);
        pair.swap(0, usdcOut, ALICE, "");
    }

    /*//////////////////////////////////////////////////////////////
                         TEST CUMULATIVE PRICES
    //////////////////////////////////////////////////////////////*/
    function testCumulativePrices() public initialMint {
        (uint256 initialPrice0, uint256 initialPrice1) = calculateCumulativePrices();

        pair.sync();
        assertEq(pair.s_price0CumulativeLast(), initialPrice0 * 0);
        assertEq(pair.s_price1CumulativeLast(), initialPrice1 * 0);

        vm.warp(1);
        pair.sync();
        assertEq(pair.s_price0CumulativeLast(), initialPrice0);
        assertEq(pair.s_price1CumulativeLast(), initialPrice1);

        vm.warp(2);
        pair.sync();
        assertEq(pair.s_price0CumulativeLast(), initialPrice0 * 2);
        assertEq(pair.s_price1CumulativeLast(), initialPrice1 * 2);

        vm.startPrank(ALICE);
        weth.transfer(address(pair), 1 ether);
        usdc.transfer(address(pair), 2000 ether);
        vm.stopPrank();
        pair.mint(ALICE);

        (uint256 newPrice0, uint256 newPrice1) = calculateCumulativePrices();

        assertEq(pair.s_price0CumulativeLast(), initialPrice0 * 2);
        assertEq(pair.s_price1CumulativeLast(), initialPrice1 * 2);

        vm.warp(3);
        pair.sync();
        assertEq(pair.s_price0CumulativeLast(), (initialPrice0 * 2) + newPrice0);
        assertEq(pair.s_price1CumulativeLast(), (initialPrice1 * 2) + newPrice1);

        vm.warp(4);
        pair.sync();
        assertEq(pair.s_price0CumulativeLast(), (initialPrice0 * 2) + newPrice0 * 2);
        assertEq(pair.s_price1CumulativeLast(), (initialPrice1 * 2) + newPrice1 * 2);

        vm.warp(6);
        pair.sync();
        assertEq(pair.s_price0CumulativeLast(), (initialPrice0 * 2) + newPrice0 * 4);
        assertEq(pair.s_price1CumulativeLast(), (initialPrice1 * 2) + newPrice1 * 4);
    }

    /*//////////////////////////////////////////////////////////////
                               SKIM TESTS
    //////////////////////////////////////////////////////////////*/
    function testSkim() public initialMint {
        uint256 skimAmount = 1 ether;

        vm.prank(BOB);
        weth.transfer(address(pair), skimAmount);

        pair.skim(ALICE);

        uint256 expectedAliceBalanceWeth = STARTING_WETH_BALANCE + skimAmount;
        uint256 expectedBobBalanceWeth = STARTING_WETH_BALANCE - 10 ether - skimAmount;

        assertEq(weth.balanceOf(ALICE), expectedAliceBalanceWeth);
        assertEq(weth.balanceOf(BOB), expectedBobBalanceWeth);
    }

    function testSkimTransferFails() public {
        ERC20MintableTransferFailed token1 = new ERC20MintableTransferFailed("TOKEN_1", "TKN1");
        token1.mint(100 ether, BOB);
        ERC20MintableTransferFailed token2 = new ERC20MintableTransferFailed("TOKEN_2", "TKN2");

        CrypticFlowPair mockPair = new CrypticFlowPair();
        mockPair.initializePair(address(token1), address(token2));

        vm.prank(BOB);
        token1.approve(address(this), 10 ether);
        token1.transferFrom(BOB, address(mockPair), 10 ether);

        vm.expectRevert(CrypticFlowPair.CrypticFlowPair__TransferFailed.selector);
        mockPair.skim(BOB);
    }

    /*//////////////////////////////////////////////////////////////
                             MINT FEE TESTS
    //////////////////////////////////////////////////////////////*/
    function testMintWithMintFeeOn() public {
        factory.setFeeTo(FEES);

        vm.startPrank(BOB);
        weth.transfer(address(pair), 10 ether);
        usdc.transfer(address(pair), 20000 ether);
        vm.stopPrank();
        pair.mint(BOB);

        uint256 expectedBalanceFeeTo = 0;

        assertEq(pair.balanceOf(FEES), expectedBalanceFeeTo);
        assertEq(factory.feeTo(), FEES);
    }

    function testMintWithFeeOnAndKLastNotZero() public {
        factory.setFeeTo(FEES);

        vm.startPrank(BOB);
        weth.transfer(address(pair), 10 ether);
        usdc.transfer(address(pair), 20000 ether);
        vm.stopPrank();
        pair.mint(BOB);

        uint256 calculateAmountOut = CrypticFlowLibrary.getAmountOut(1 ether, 10 ether, 20000 ether);
        vm.prank(ALICE);
        weth.transfer(address(pair), 1 ether);
        pair.swap(0, calculateAmountOut, BOB, "");

        vm.startPrank(BOB);
        weth.transfer(address(pair), 5 ether);
        usdc.transfer(address(pair), 10000 ether);
        vm.stopPrank();
        pair.mint(BOB);

        uint256 expectedBalanceFeeTo = 0.010164869478575765 ether;

        assertEq(pair.balanceOf(FEES), expectedBalanceFeeTo);
    }

    function testBurnWithFeeOnAndKLastNotZero() public {
        factory.setFeeTo(FEES);

        vm.startPrank(BOB);
        weth.transfer(address(pair), 10 ether);
        usdc.transfer(address(pair), 20000 ether);
        vm.stopPrank();
        pair.mint(BOB);

        uint256 calculateAmountOut = CrypticFlowLibrary.getAmountOut(2000 ether, 20000 ether, 10 ether);
        vm.prank(ALICE);
        usdc.transfer(address(pair), 2000 ether);
        pair.swap(calculateAmountOut, 0, ALICE, "");

        (uint256 reserveWeth, uint256 reserveUsdc) = pair.getReserves();

        uint256 bobLpBalance = pair.balanceOf(BOB);
        vm.prank(BOB);
        pair.transfer(address(pair), bobLpBalance);
        (uint256 amountWeth, uint256 amountUsdc) = pair.burn(BOB);

        uint256 expectedKLast = (reserveWeth - amountWeth) * (reserveUsdc - amountUsdc);
        uint256 expectedBalanceFeeTo = 10164869478575767;

        assertEq(pair.kLast(), expectedKLast);
        assertEq(pair.balanceOf(FEES), expectedBalanceFeeTo);
    }

    function testFeeWasOnButWasTurnedOff() public {
        factory.setFeeTo(FEES);

        vm.startPrank(BOB);
        weth.transfer(address(pair), 10 ether);
        usdc.transfer(address(pair), 20000 ether);
        vm.stopPrank();
        pair.mint(BOB);

        uint256 kLastBefore = pair.kLast();

        factory.setFeeTo(address(0));

        uint256 bobLpBalance = pair.balanceOf(BOB);
        vm.prank(BOB);
        pair.transfer(address(pair), bobLpBalance);
        pair.burn(BOB);

        uint256 expectedKlastBefore = 10 ether * 20000 ether;
        uint256 expectedKLastAfter = 0;

        assertEq(kLastBefore, expectedKlastBefore);
        assertEq(pair.kLast(), expectedKLastAfter);
    }

    /*//////////////////////////////////////////////////////////////
                            FLASH LOAN TESTS
    //////////////////////////////////////////////////////////////*/
    function testFlashLoan() public initialMint {
        uint256 flashloanAmount = 1 ether;
        uint256 flashloanFee = ((flashloanAmount * 1000) / 997) - flashloanAmount + 1;
        Flashloaner fl = new Flashloaner();

        vm.prank(ALICE);
        weth.transfer(address(fl), flashloanFee);

        fl.flashloan(address(pair), flashloanAmount, 0, address(weth));

        uint256 expectedFlBalance = 0;
        uint256 expectedPairBalanceWeth = 10 ether + flashloanFee;

        assertEq(weth.balanceOf(address(fl)), expectedFlBalance);
        assertEq(weth.balanceOf(address(pair)), expectedPairBalanceWeth);
    }

    function testFlashLoanInsufficientFlashLoanAmount() public initialMint {
        uint256 flashloanAmount = 1 ether;
        uint256 flashloanFee = ((flashloanAmount * 1000) / 997) - flashloanAmount + 1;
        Flashloaner fl = new Flashloaner();

        vm.prank(ALICE);
        weth.transfer(address(fl), flashloanFee);

        vm.expectRevert(Flashloaner.Flashloaner__InsufficientFlashLoanAmount.selector);
        fl.flashloan(address(pair), 0, flashloanAmount, address(weth));
    }
}

contract Flashloaner {
    error Flashloaner__InsufficientFlashLoanAmount();

    uint256 expectedLoanAmount;

    function flashloan(address pairAddress, uint256 amount0Out, uint256 amount1Out, address tokenAddress) public {
        if (amount0Out > 0) expectedLoanAmount = amount0Out;
        if (amount1Out > 0) expectedLoanAmount = amount1Out;

        CrypticFlowPair(pairAddress).swap(amount0Out, amount1Out, address(this), abi.encode(tokenAddress));
    }

    function crypticFlowCall(address, /*sender*/ uint256, /*amount0Out*/ uint256, /*amount1Out*/ bytes calldata data)
        public
    {
        address tokenAddress = abi.decode(data, (address));
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));

        if (balance < expectedLoanAmount) revert Flashloaner__InsufficientFlashLoanAmount();

        IERC20(tokenAddress).transfer(msg.sender, balance);
    }
}
