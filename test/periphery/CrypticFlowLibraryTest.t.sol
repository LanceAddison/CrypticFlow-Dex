// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {CrypticFlowLibrary} from "../../src/libraries/CrypticFlowLibrary.sol";
import {CrypticFlowFactory} from "../../src/CrypticFlowFactory.sol";
import {CrypticFlowPair} from "../../src/CrypticFlowPair.sol";
import {DeployCrypticFlowFactory} from "../../script/DeployCrypticFlowFactory.s.sol";
import {ERC20Mintable} from "../mocks/ERC20Mintable.sol";

contract CrypticFlowLibraryTest is Test {
    DeployCrypticFlowFactory deployer;
    CrypticFlowFactory factory;

    address public BOB = makeAddr("bob");
    uint256 constant STARTING_WETH_BALANCE = 100 ether;
    uint256 constant STARING_WBTC_BALANCE = 10 ether;
    uint256 constant STARTING_USDC_BALANCE = 1000000 ether;
    uint256 constant STARTING_DAI_BALANCE = 1000000 ether;

    ERC20Mintable private weth;
    ERC20Mintable private wbtc;
    ERC20Mintable private usdc;
    ERC20Mintable private dai;

    CrypticFlowPair pair;
    CrypticFlowPair pair2;
    CrypticFlowPair pair3;

    function setUp() public {
        deployer = new DeployCrypticFlowFactory();
        factory = deployer.run();

        weth = new ERC20Mintable("WETH", "WETH");
        wbtc = new ERC20Mintable("WBTC", "WBTC");
        usdc = new ERC20Mintable("USDC", "USDC");
        dai = new ERC20Mintable("DAI", "DAI");

        weth.mint(STARTING_WETH_BALANCE, BOB);
        wbtc.mint(STARING_WBTC_BALANCE, BOB);
        usdc.mint(STARTING_USDC_BALANCE, BOB);
        dai.mint(STARTING_DAI_BALANCE, BOB);

        address pairAddress = factory.createPair(address(weth), address(wbtc));
        pair = CrypticFlowPair(pairAddress);
        pairAddress = factory.createPair(address(wbtc), address(usdc));
        pair2 = CrypticFlowPair(pairAddress);
        pairAddress = factory.createPair(address(usdc), address(dai));
        pair3 = CrypticFlowPair(pairAddress);
    }

    modifier initialMint() {
        vm.startPrank(BOB);
        weth.transfer(address(pair), 10 ether);
        wbtc.transfer(address(pair), 1 ether);
        pair.mint(BOB);
        vm.stopPrank();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           GET RESERVES TESTS
    //////////////////////////////////////////////////////////////*/
    function testGetReserves() public initialMint {
        (uint256 wethReserves, uint256 wbtcReserves) =
            CrypticFlowLibrary.getReserves(address(factory), address(weth), address(wbtc));

        uint256 expectedWethReserves = 10 ether;
        uint256 expectedWbtcReserves = 1 ether;

        assertEq(wethReserves, expectedWethReserves);
        assertEq(wbtcReserves, expectedWbtcReserves);
    }

    /*//////////////////////////////////////////////////////////////
                              QUOTE TESTS
    //////////////////////////////////////////////////////////////*/
    function testCanGetQuote() public pure {
        uint256 amountOut = CrypticFlowLibrary.quote(1 ether, 10 ether, 1 ether);
        uint256 expectedAmountOut = 0.1 ether;
        assertEq(amountOut, expectedAmountOut);

        amountOut = CrypticFlowLibrary.quote(0.5 ether, 1 ether, 10 ether);
        expectedAmountOut = 5 ether;
        assertEq(amountOut, expectedAmountOut);

        amountOut = CrypticFlowLibrary.quote(20 ether, 10 ether, 1 ether);
        expectedAmountOut = 2 ether;
        assertEq(amountOut, expectedAmountOut);
    }

    function testQuoteInsufficientAmount() public {
        vm.expectRevert(CrypticFlowLibrary.CrypticFlowLibrary__InsufficientAmount.selector);
        CrypticFlowLibrary.quote(0, 10 ether, 1 ether);
    }

    function testQuoteInsufficientLiquidity() public {
        vm.expectRevert(CrypticFlowLibrary.CrypticFlowLibrary__InsufficientLiquidity.selector);
        CrypticFlowLibrary.quote(1 ether, 0, 1 ether);

        vm.expectRevert(CrypticFlowLibrary.CrypticFlowLibrary__InsufficientLiquidity.selector);
        CrypticFlowLibrary.quote(1 ether, 10 ether, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          GET AMOUNT OUT TESTS
    //////////////////////////////////////////////////////////////*/
    function testGetAmountOut() public pure {
        uint256 amountOut = CrypticFlowLibrary.getAmountOut(1 ether, 10 ether, 1 ether);
        uint256 expectedAmountOut = 0.090661089388014913 ether;
        assertEq(amountOut, expectedAmountOut);

        amountOut = CrypticFlowLibrary.getAmountOut(0.1 ether, 1 ether, 10 ether);
        expectedAmountOut = 0.906610893880149131 ether;
        assertEq(amountOut, expectedAmountOut);
    }

    function testGetAmountOutInsufficientAmount() public {
        vm.expectRevert(CrypticFlowLibrary.CrypticFlowLibrary__InsufficientAmount.selector);
        CrypticFlowLibrary.getAmountOut(0, 10 ether, 1 ether);
    }

    function testGetAmountOutInsufficientLiquidity() public {
        vm.expectRevert(CrypticFlowLibrary.CrypticFlowLibrary__InsufficientLiquidity.selector);
        CrypticFlowLibrary.getAmountOut(1 ether, 0, 1 ether);

        vm.expectRevert(CrypticFlowLibrary.CrypticFlowLibrary__InsufficientLiquidity.selector);
        CrypticFlowLibrary.getAmountOut(1 ether, 10 ether, 0);
    }

    /*//////////////////////////////////////////////////////////////
                          GET AMOUNT IN TESTS
    //////////////////////////////////////////////////////////////*/
    function testGetAmountIn() public pure {
        uint256 amountIn = CrypticFlowLibrary.getAmountIn(0.1 ether, 10 ether, 1 ether);
        uint256 expectedAmountIn = 1.114454474534715257 ether;
        assertEq(amountIn, expectedAmountIn);

        amountIn = CrypticFlowLibrary.getAmountIn(1 ether, 1 ether, 10 ether);
        expectedAmountIn = 0.111445447453471526 ether;
        assertEq(amountIn, expectedAmountIn);
    }

    function testGetAmountInInsufficientAmount() public {
        vm.expectRevert(CrypticFlowLibrary.CrypticFlowLibrary__InsufficientAmount.selector);
        CrypticFlowLibrary.getAmountIn(0, 1 ether, 10 ether);
    }

    function testGetAmountInInsufficientLiquidity() public {
        vm.expectRevert(CrypticFlowLibrary.CrypticFlowLibrary__InsufficientLiquidity.selector);
        CrypticFlowLibrary.getAmountIn(1 ether, 0, 10 ether);

        vm.expectRevert(CrypticFlowLibrary.CrypticFlowLibrary__InsufficientLiquidity.selector);
        CrypticFlowLibrary.getAmountIn(0.1 ether, 10 ether, 0);
    }

    /*//////////////////////////////////////////////////////////////
                         GET AMOUNTS OUT TESTS
    //////////////////////////////////////////////////////////////*/
    function testGetAmountsOut() public initialMint {
        vm.startPrank(BOB);
        wbtc.transfer(address(pair2), 1 ether);
        usdc.transfer(address(pair2), 20000 ether);
        pair2.mint(BOB);

        usdc.transfer(address(pair3), 20000 ether);
        dai.transfer(address(pair3), 20000 ether);
        pair3.mint(BOB);
        vm.stopPrank();

        address[] memory path = new address[](4);
        path[0] = address(weth);
        path[1] = address(wbtc);
        path[2] = address(usdc);
        path[3] = address(dai);

        uint256[] memory amounts = CrypticFlowLibrary.getAmountsOut(address(factory), 1 ether, path);

        uint256 expectedAmountWeth = 1 ether;
        uint256 expectedAmountWbtc = 0.090661089388014913 ether;
        uint256 expectedAmountUsdc = 1657.92386612335959119 ether;
        uint256 expectedAmountDai = 1526.766641320567843623 ether;

        assertEq(amounts[0], expectedAmountWeth);
        assertEq(amounts[1], expectedAmountWbtc);
        assertEq(amounts[2], expectedAmountUsdc);
        assertEq(amounts[3], expectedAmountDai);
    }

    function testGetAmountsOutInvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = address(dai);

        vm.expectRevert(CrypticFlowLibrary.CrypticFlowLibrary__InvalidPath.selector);
        CrypticFlowLibrary.getAmountsOut(address(factory), 1 ether, path);
    }

    /*//////////////////////////////////////////////////////////////
                          GET AMOUNTS IN TESTS
    //////////////////////////////////////////////////////////////*/
    function testGetAmountsIn() public initialMint {
        vm.startPrank(BOB);
        wbtc.transfer(address(pair2), 1 ether);
        usdc.transfer(address(pair2), 20000 ether);
        pair2.mint(BOB);

        usdc.transfer(address(pair3), 20000 ether);
        dai.transfer(address(pair3), 20000 ether);
        pair3.mint(BOB);
        vm.stopPrank();

        address[] memory path = new address[](4);
        path[0] = address(weth);
        path[1] = address(wbtc);
        path[2] = address(usdc);
        path[3] = address(dai);

        uint256[] memory amounts = CrypticFlowLibrary.getAmountsIn(address(factory), 2000 ether, path);

        uint256 expectedAmountDai = 2000 ether;
        uint256 expectedAmountUsdc = 2228.908949069430513764 ether;
        uint256 expectedAmountWbtc = 0.125800705767119495 ether;
        uint256 expectedAmountWeth = 1.443369313267817333 ether;

        assertEq(amounts[3], expectedAmountDai);
        assertEq(amounts[2], expectedAmountUsdc);
        assertEq(amounts[1], expectedAmountWbtc);
        assertEq(amounts[0], expectedAmountWeth);
    }

    function testGetAmountsInInvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = address(weth);

        vm.expectRevert(CrypticFlowLibrary.CrypticFlowLibrary__InvalidPath.selector);
        CrypticFlowLibrary.getAmountsIn(address(factory), 2000 ether, path);
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL PURE FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/
    function testGetPairFor() public view {
        address pairAddress = CrypticFlowLibrary._pairFor(address(factory), address(weth), address(wbtc));
        address expectedPairAddress = factory.getPair(address(weth), address(wbtc));
        assertEq(pairAddress, expectedPairAddress);
    }

    function testGetPairForFactoryDoesntExist() public view {
        address pairAddress = CrypticFlowLibrary._pairFor(address(0), address(weth), address(wbtc));
        address expectedPairAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(0),
                            keccak256(abi.encodePacked(address(weth), address(wbtc))),
                            keccak256(type(CrypticFlowPair).creationCode)
                        )
                    )
                )
            )
        );

        assertEq(pairAddress, expectedPairAddress);
    }

    function testGetPairForTokensSortedCorrectly() public view {
        address pairAddress = CrypticFlowLibrary._pairFor(address(factory), address(wbtc), address(weth));
        address expectedPairAddress = factory.getPair(address(weth), address(wbtc));
        assertEq(pairAddress, expectedPairAddress);
    }
}
