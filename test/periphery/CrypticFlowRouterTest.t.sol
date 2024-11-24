// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {DeployCrypticFlowRouter} from "../../script/DeployCrypticFlowRouter.s.sol";
import {CrypticFlowRouter} from "../../src/CrypticFlowRouter.sol";
import {CrypticFlowFactory} from "../../src/CrypticFlowFactory.sol";
import {CrypticFlowPair, ICrypticFlowPair} from "../../src/CrypticFlowPair.sol";
import {CrypticFlowLibrary} from "../../src/libraries/CrypticFlowLibrary.sol";
import {ERC20Mintable} from "../mocks/ERC20Mintable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract CrypticFlowRouterTest is Test {
    CrypticFlowRouter router;
    CrypticFlowFactory factory;
    DeployCrypticFlowRouter deployer;

    address public BOB = makeAddr("bob");
    address public ALICE = makeAddr("alice");
    uint256 constant STARTING_WETH_BALANCE = 100 ether;
    uint256 constant STARTING_USDC_BALANCE = 1000000 ether;
    uint256 constant STARTING_DAI_BALANCE = 1000000 ether;

    ERC20Mintable private weth;
    ERC20Mintable private usdc;
    ERC20Mintable private dai;

    function setUp() public {
        deployer = new DeployCrypticFlowRouter();
        (factory, router) = deployer.run();

        weth = new ERC20Mintable("WETH", "WETH");
        usdc = new ERC20Mintable("USDC", "USDC");
        dai = new ERC20Mintable("DAI", "DAI");

        weth.mint(STARTING_WETH_BALANCE, BOB);
        usdc.mint(STARTING_USDC_BALANCE, BOB);
        dai.mint(STARTING_DAI_BALANCE, BOB);
        weth.mint(STARTING_WETH_BALANCE, ALICE);
        usdc.mint(STARTING_USDC_BALANCE, ALICE);
        dai.mint(STARTING_DAI_BALANCE, ALICE);
    }

    modifier addInitialLiquidity() {
        vm.startPrank(BOB);
        weth.approve(address(router), 10 ether);
        usdc.approve(address(router), 20000 ether);
        router.addLiquidity(address(weth), address(usdc), 10 ether, 20000 ether, 10 ether, 20000 ether, BOB);
        vm.stopPrank();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          ADD LIQUIDITY TESTS
    //////////////////////////////////////////////////////////////*/
    function testAddLiquidityPairAddressIsCorrect() public {
        uint256 amountADesired = 10 ether;
        uint256 amountBDesired = 20000 ether;
        uint256 amountAMin = 10 ether;
        uint256 amountBMin = 20000 ether;

        vm.startPrank(BOB);
        weth.approve(address(router), amountADesired);
        usdc.approve(address(router), amountBDesired);
        router.addLiquidity(address(weth), address(usdc), amountADesired, amountBDesired, amountAMin, amountBMin, BOB);
        vm.stopPrank();

        address expectedPairAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(factory),
                            keccak256(abi.encodePacked(address(weth), address(usdc))),
                            keccak256(type(CrypticFlowPair).creationCode)
                        )
                    )
                )
            )
        );

        assertEq(factory.getPair(address(weth), address(usdc)), expectedPairAddress);
    }

    function testAddLiquidityNoPair() public {
        vm.startPrank(BOB);
        weth.approve(address(router), 10 ether);
        usdc.approve(address(router), 20000 ether);
        (,, uint256 liquidity) =
            router.addLiquidity(address(weth), address(usdc), 10 ether, 20000 ether, 10 ether, 20000 ether, BOB);
        vm.stopPrank();

        uint256 expectedBobWethBalance = STARTING_WETH_BALANCE - 10 ether;
        uint256 expectedBobUsdcBalance = STARTING_USDC_BALANCE - 20000 ether;

        assertEq(weth.balanceOf(BOB), expectedBobWethBalance);
        assertEq(usdc.balanceOf(BOB), expectedBobUsdcBalance);
        assertEq(ICrypticFlowPair(factory.getPair(address(weth), address(usdc))).balanceOf(BOB), liquidity);
    }

    function testAddLiquidityAlreadyPair() public addInitialLiquidity {
        vm.startPrank(ALICE);
        weth.approve(address(router), 10 ether);
        usdc.approve(address(router), 20000 ether);
        (uint256 amountWeth, uint256 amountUsdc, uint256 liquidity) =
            router.addLiquidity(address(weth), address(usdc), 10 ether, 20000 ether, 9 ether, 18000 ether, ALICE);
        vm.stopPrank();

        uint256 expectedAliceWethBalance = STARTING_WETH_BALANCE - amountWeth;
        uint256 expectedAliceUsdcBalance = STARTING_USDC_BALANCE - amountUsdc;

        assertEq(weth.balanceOf(ALICE), expectedAliceWethBalance);
        assertEq(usdc.balanceOf(ALICE), expectedAliceUsdcBalance);
        assertEq(ICrypticFlowPair(factory.getPair(address(weth), address(usdc))).balanceOf(ALICE), liquidity);
    }

    function testFuzzAddLiquidity(uint256 amountWethDesired) public addInitialLiquidity {
        amountWethDesired = bound(amountWethDesired, 1, weth.balanceOf(BOB));
        uint256 amountUsdcDesired = amountWethDesired * 2000;
        uint256 amountWethMin = (amountWethDesired * 99) / 100;
        uint256 amountUsdcMin = (amountUsdcDesired * 99) / 100;

        vm.startPrank(BOB);
        weth.approve(address(router), amountWethDesired);
        usdc.approve(address(router), amountUsdcDesired);
        router.addLiquidity(
            address(weth), address(usdc), amountWethDesired, amountUsdcDesired, amountWethMin, amountUsdcMin, BOB
        );
        vm.stopPrank();
    }

    function testAddLiquidityAmountBOptimalTooHighAmountAOk() public addInitialLiquidity {
        uint256 amountADesired = 10 ether;
        uint256 amountBDesired = 19000 ether;
        uint256 amountAMin = 9 ether;
        uint256 amountBMin = 18000 ether;

        uint256 pairTotalSupplyBefore = ICrypticFlowPair(factory.getPair(address(weth), address(usdc))).totalSupply();

        vm.startPrank(ALICE);
        weth.approve(address(router), amountADesired);
        usdc.approve(address(router), amountBDesired);
        (uint256 amountWeth, uint256 amountUsdc, uint256 liquidity) = router.addLiquidity(
            address(weth), address(usdc), amountADesired, amountBDesired, amountAMin, amountBMin, ALICE
        );
        vm.stopPrank();

        uint256 expectedAmountWeth = 9.5 ether;
        uint256 expectedAmountUsdc = amountBDesired;
        uint256 expectedLiquidity = (pairTotalSupplyBefore * expectedAmountWeth) / 10 ether;

        assertEq(amountWeth, expectedAmountWeth);
        assertEq(amountUsdc, expectedAmountUsdc);
        assertEq(liquidity, expectedLiquidity);
    }

    function testCantAddLiquidityIfAmountBOptimalTooLow() public addInitialLiquidity {
        uint256 amountADesired = 1 ether;
        uint256 amountBDesired = 20000 ether;
        uint256 amountAMin = 0.9 ether;
        uint256 amountBMin = 18000 ether;

        vm.startPrank(ALICE);
        weth.approve(address(router), amountADesired);
        usdc.approve(address(router), amountBDesired);
        vm.expectRevert(CrypticFlowRouter.CrypticFlowRouter__AmountBInsufficient.selector);
        router.addLiquidity(address(weth), address(usdc), amountADesired, amountBDesired, amountAMin, amountBMin, ALICE);
        vm.stopPrank();
    }

    function testCantAddLiquidityIfAmountAOptimalTooLow() public addInitialLiquidity {
        uint256 amountADesired = 10 ether;
        uint256 amountBDesired = 2000 ether;
        uint256 amountAMin = 9 ether;
        uint256 amountBMin = 1800 ether;

        vm.startPrank(ALICE);
        weth.approve(address(router), amountADesired);
        usdc.approve(address(router), amountBDesired);
        vm.expectRevert(CrypticFlowRouter.CrypticFlowRouter__AmountAInsufficient.selector);
        router.addLiquidity(address(weth), address(usdc), amountADesired, amountBDesired, amountAMin, amountBMin, ALICE);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         REMOVE LIQUIDITY TESTS
    //////////////////////////////////////////////////////////////*/
    function testRemoveLiquidity() public addInitialLiquidity {
        address pair = factory.getPair(address(weth), address(usdc));
        uint256 bobLpTokenBalance = ICrypticFlowPair(pair).balanceOf(BOB);

        vm.startPrank(BOB);
        CrypticFlowPair(pair).approve(address(router), bobLpTokenBalance);
        (uint256 wethAmount, uint256 usdcAmount) =
            router.removeLiquidity(address(weth), address(usdc), bobLpTokenBalance, 9.9 ether, 19800 ether, BOB);
        vm.stopPrank();

        uint256 expectedBobWethBalance = (STARTING_WETH_BALANCE - 10 ether) + wethAmount;
        uint256 expectedBobUsdcBalance = (STARTING_USDC_BALANCE - 20000 ether) + usdcAmount;
        uint256 expectedBobLpTokenBalance = 0;

        assertEq(weth.balanceOf(BOB), expectedBobWethBalance);
        assertEq(usdc.balanceOf(BOB), expectedBobUsdcBalance);
        assertEq(ICrypticFlowPair(pair).balanceOf(BOB), expectedBobLpTokenBalance);
    }

    function testRemoveLiquidityPartially() public addInitialLiquidity {
        address pair = factory.getPair(address(weth), address(usdc));
        uint256 bobLpToRemove = 100 ether;
        uint256 totalLpTokensBefore = ICrypticFlowPair(pair).totalSupply();
        (uint256 wethReservesBefore, uint256 usdcReservesBefore) = ICrypticFlowPair(pair).getReserves();

        vm.startPrank(BOB);
        CrypticFlowPair(pair).approve(address(router), bobLpToRemove);
        router.removeLiquidity(address(weth), address(usdc), bobLpToRemove, 2.2 ether, 4450 ether, BOB);
        vm.stopPrank();

        (uint256 wethReservesAfter, uint256 usdcReservesAfter) = ICrypticFlowPair(pair).getReserves();
        uint256 wethToRemove = (bobLpToRemove * 10 ether) / totalLpTokensBefore;
        uint256 usdcToRemove = (bobLpToRemove * 20000 ether) / totalLpTokensBefore;

        uint256 expectedBobWethBalance = (STARTING_WETH_BALANCE - 10 ether) + wethToRemove;
        uint256 expectedBobUsdcBalance = (STARTING_USDC_BALANCE - 20000 ether) + usdcToRemove;
        uint256 expectedWethReserves = wethReservesBefore - wethToRemove;
        uint256 expectedUsdcReserves = usdcReservesBefore - usdcToRemove;
        uint256 expectedLpTotalSupply = totalLpTokensBefore - bobLpToRemove;

        assertEq(weth.balanceOf(BOB), expectedBobWethBalance);
        assertEq(usdc.balanceOf(BOB), expectedBobUsdcBalance);
        assertEq(wethReservesAfter, expectedWethReserves);
        assertEq(usdcReservesAfter, expectedUsdcReserves);
        assertEq(ICrypticFlowPair(pair).totalSupply(), expectedLpTotalSupply);
    }

    function testRemoveLiquidityAmountAInsufficient() public addInitialLiquidity {
        address pair = factory.getPair(address(weth), address(usdc));
        uint256 bobLpBalance = ICrypticFlowPair(pair).balanceOf(BOB);

        vm.startPrank(BOB);
        CrypticFlowPair(pair).approve(address(router), bobLpBalance);
        vm.expectRevert(CrypticFlowRouter.CrypticFlowRouter__AmountAInsufficient.selector);
        router.removeLiquidity(address(weth), address(usdc), bobLpBalance, 10 ether, 19800 ether, BOB);
        vm.stopPrank();
    }

    function testRemoveLiquidityAmountBInsufficient() public addInitialLiquidity {
        address pair = factory.getPair(address(weth), address(usdc));
        uint256 bobLpBalance = ICrypticFlowPair(pair).balanceOf(BOB);

        vm.startPrank(BOB);
        CrypticFlowPair(pair).approve(address(router), bobLpBalance);
        vm.expectRevert(CrypticFlowRouter.CrypticFlowRouter__AmountBInsufficient.selector);
        router.removeLiquidity(address(weth), address(usdc), bobLpBalance, 9.9 ether, 20000 ether, BOB);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                   SWAP EXACT TOKENS FOR TOKENS TESTS
    //////////////////////////////////////////////////////////////*/
    function testSwapExactTokensForTokens() public addInitialLiquidity {
        uint256 amountWethIn = 1 ether;
        uint256 amountUsdcOutMin = 1800 ether;
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);

        vm.startPrank(ALICE);
        weth.approve(address(router), amountWethIn);
        uint256[] memory amounts = router.swapExactTokensForTokens(amountWethIn, amountUsdcOutMin, path, ALICE);
        vm.stopPrank();

        (uint256 wethReserves, uint256 usdcReserves) =
            ICrypticFlowPair(factory.getPair(address(weth), address(usdc))).getReserves();

        uint256 expectedAliceWethBalance = STARTING_WETH_BALANCE - amountWethIn;
        uint256 expectedAliceUsdcBalance = STARTING_USDC_BALANCE + amounts[1];
        uint256 expectedWethReserves = 10 ether + amountWethIn;
        uint256 expectedUsdcReserves = 20000 ether - amounts[1];

        assertEq(weth.balanceOf(ALICE), expectedAliceWethBalance);
        assertEq(usdc.balanceOf(ALICE), expectedAliceUsdcBalance);
        assertEq(wethReserves, expectedWethReserves);
        assertEq(usdcReserves, expectedUsdcReserves);
    }

    function testFuzzSwapExactTokensForTokens(uint256 amountWethIn) public addInitialLiquidity {
        (uint256 wethReserves,) = ICrypticFlowPair(factory.getPair(address(weth), address(usdc))).getReserves();
        amountWethIn = bound(amountWethIn, 1, wethReserves);
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);

        uint256 amountUsdcOutMin = CrypticFlowLibrary.getAmountOut(amountWethIn, 10 ether, 20000 ether);
        vm.startPrank(BOB);
        weth.approve(address(router), amountWethIn);
        router.swapExactTokensForTokens(amountWethIn, amountUsdcOutMin, path, BOB);
        vm.stopPrank();
    }

    function testSwapExactTokensForTokensMultiplePairs() public addInitialLiquidity {
        uint256 amountUsdc = 20000 ether;
        uint256 amountDai = 20000 ether;
        vm.startPrank(BOB);
        usdc.approve(address(router), amountUsdc);
        dai.approve(address(router), amountDai);
        router.addLiquidity(address(usdc), address(dai), amountUsdc, amountDai, amountUsdc, amountDai, BOB);
        vm.stopPrank();

        uint256 amountWethIn = 1 ether;
        uint256 amountDaiOutMin = 1650 ether;
        address[] memory path = new address[](3);
        path[0] = address(weth);
        path[1] = address(usdc);
        path[2] = address(dai);

        vm.startPrank(ALICE);
        weth.approve(address(router), amountWethIn);
        uint256[] memory amounts = router.swapExactTokensForTokens(amountWethIn, amountDaiOutMin, path, ALICE);
        vm.stopPrank();

        (uint256 wethReserves, uint256 usdcReserves) =
            ICrypticFlowPair(factory.getPair(address(weth), address(usdc))).getReserves();
        (uint256 usdcReservesPair2, uint256 daiReserves) =
            ICrypticFlowPair(factory.getPair(address(usdc), address(dai))).getReserves();

        uint256 expectedAliceWethBalance = STARTING_WETH_BALANCE - amountWethIn;
        uint256 expectedAliceDaiBalance = STARTING_DAI_BALANCE + amounts[2];
        uint256 expectedWethReserves = 10 ether + amounts[0];
        uint256 expectedUsdcReserves = 20000 ether - amounts[1];
        uint256 expectedUsdcReservesPair2 = 20000 ether - amounts[2];
        uint256 expectedDaiReserves = 20000 ether + amounts[1];

        assertEq(weth.balanceOf(ALICE), expectedAliceWethBalance);
        assertEq(dai.balanceOf(ALICE), expectedAliceDaiBalance);
        assertEq(wethReserves, expectedWethReserves);
        assertEq(usdcReserves, expectedUsdcReserves);
        assertEq(usdcReservesPair2, expectedUsdcReservesPair2);
        assertEq(daiReserves, expectedDaiReserves);
    }

    function testSwapExactTokensForTokensAmountOutInsufficient() public addInitialLiquidity {
        uint256 amountWethIn = 1 ether;
        uint256 amountUsdcOut = 2000 ether;
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);

        vm.startPrank(ALICE);
        weth.approve(address(router), amountWethIn);
        vm.expectRevert(CrypticFlowRouter.CrypticFlowRouter__AmountOutInsufficient.selector);
        router.swapExactTokensForTokens(amountWethIn, amountUsdcOut, path, ALICE);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                   SWAP TOKENS FOR EXACT TOKENS TESTS
    //////////////////////////////////////////////////////////////*/
    function testCanSwapTokensForExactTokens() public addInitialLiquidity {
        uint256 wethAmount = 10 ether;
        uint256 daiAmount = 20000 ether;
        vm.startPrank(BOB);
        weth.approve(address(router), wethAmount);
        dai.approve(address(router), daiAmount);
        router.addLiquidity(address(weth), address(dai), wethAmount, daiAmount, wethAmount, daiAmount, BOB);
        vm.stopPrank();

        uint256 usdcAmountOut = 1600 ether;
        uint256 daiAmountInMax = 2000 ether;
        address[] memory path = new address[](3);
        path[0] = address(dai);
        path[1] = address(weth);
        path[2] = address(usdc);

        vm.startPrank(ALICE);
        dai.approve(address(router), daiAmountInMax);
        uint256[] memory amounts = router.swapTokensForExactTokens(usdcAmountOut, daiAmountInMax, path, ALICE);
        vm.stopPrank();

        uint256 expectedAliceUsdcBalance = STARTING_USDC_BALANCE + amounts[2];
        uint256 expectedAliceDaiBalance = STARTING_DAI_BALANCE - amounts[0];

        assertEq(usdc.balanceOf(ALICE), expectedAliceUsdcBalance);
        assertEq(dai.balanceOf(ALICE), expectedAliceDaiBalance);
    }

    function testFuzzCanSwapTokensForExactTokensFeeImpactOnK(uint256 amountWethOut, uint256 numSwaps)
        public
        addInitialLiquidity
    {
        numSwaps = numSwaps % 100;
        (uint256 startingWethReserves, uint256 startingUsdcReserves) =
            ICrypticFlowPair(factory.getPair(address(weth), address(usdc))).getReserves();
        amountWethOut = bound(amountWethOut, 1, startingWethReserves / 10);

        address[] memory path = new address[](2);
        path[0] = address(usdc);
        path[1] = address(weth);
        uint256 kBefore = startingWethReserves * startingUsdcReserves;

        for (uint256 i = 0; i < numSwaps; i++) {
            (uint256 wethReserves, uint256 usdcReserves) =
                ICrypticFlowPair(factory.getPair(address(weth), address(usdc))).getReserves();

            amountWethOut = bound(amountWethOut, 1, wethReserves / 10);

            uint256 amountUsdcInMax = CrypticFlowLibrary.getAmountIn(amountWethOut, usdcReserves, wethReserves);

            if (amountUsdcInMax > usdc.balanceOf(BOB)) {
                amountWethOut = usdc.balanceOf(BOB) / usdcReserves * amountWethOut;
                amountUsdcInMax = usdc.balanceOf(BOB);
            }

            vm.startPrank(BOB);
            usdc.approve(address(router), amountUsdcInMax);
            router.swapTokensForExactTokens(amountWethOut, amountUsdcInMax, path, BOB);
            vm.stopPrank();

            uint256 kAfter = wethReserves * usdcReserves;
            assert(kAfter >= kBefore);
        }
    }

    function testCanSwapTokensForExactTokensExcessInputAmount() public addInitialLiquidity {
        uint256 wethAmount = 10 ether;
        uint256 daiAmount = 20000 ether;
        vm.startPrank(BOB);
        weth.approve(address(router), wethAmount);
        dai.approve(address(router), daiAmount);
        router.addLiquidity(address(weth), address(dai), wethAmount, daiAmount, wethAmount, daiAmount, BOB);
        vm.stopPrank();

        uint256 daiAmountOut = 2100 ether;
        uint256 usdcAmountInMax = 2000 ether;
        address[] memory path = new address[](3);
        path[0] = address(usdc);
        path[1] = address(weth);
        path[2] = address(dai);

        vm.startPrank(ALICE);
        usdc.approve(address(router), usdcAmountInMax);
        vm.expectRevert(CrypticFlowRouter.CrypticFlowRouter__ExcessiveInputAmount.selector);
        router.swapTokensForExactTokens(daiAmountOut, usdcAmountInMax, path, ALICE);
        vm.stopPrank();
    }
}
