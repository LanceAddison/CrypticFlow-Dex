// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {CrypticFlowFactory} from "../../src/CrypticFlowFactory.sol";
import {DeployCrypticFlowFactory} from "../../script/DeployCrypticFlowFactory.s.sol";
import {ERC20Mintable} from "../mocks/ERC20Mintable.sol";
import {ICrypticFlowPair} from "../../src/interfaces/ICrypticFlowPair.sol";

contract CrypticFlowFactoryTest is Test {
    CrypticFlowFactory factory;
    DeployCrypticFlowFactory deployer;

    address public BOB = makeAddr("bob");
    address public FEES = makeAddr("feeTo");
    uint256 public constant STARTING_WETH_BALANCE = 100 ether;
    uint256 public constant STARTING_USDC_BALANCE = 1000000 ether;

    uint256 public constant WETH_INITIAL_LIQUIDITY = 1 ether;
    uint256 public constant USDC_INITIAL_LIQUIDITY = 2000 ether;

    address public initialPair;

    ERC20Mintable private weth;
    ERC20Mintable private usdc;

    function setUp() public {
        deployer = new DeployCrypticFlowFactory();
        factory = deployer.run();

        weth = new ERC20Mintable("WETH", "WETH");
        usdc = new ERC20Mintable("USDC", "USDC");

        weth.mint(STARTING_WETH_BALANCE, BOB);
        usdc.mint(STARTING_USDC_BALANCE, BOB);
    }

    modifier createInitialPair(address token0, address token1) {
        initialPair = factory.createPair(token0, token1);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           CREATE PAIR TESTS
    //////////////////////////////////////////////////////////////*/
    function testCanCreatePair() public {
        address pair;
        pair = factory.createPair(address(weth), address(usdc));

        address expectedPair = factory.allPairs(0);

        assertEq(pair, expectedPair);
    }

    function testTokensCantBeTheSame() public {
        vm.expectRevert(CrypticFlowFactory.CrypticFlowFactory__TokensCantBeTheSame.selector);
        factory.createPair(address(weth), address(weth));
    }

    function testTokenCantBeAddressZero() public {
        vm.expectRevert(CrypticFlowFactory.CrypticFlowFactory__TokenCantBeAddressZero.selector);
        factory.createPair(address(weth), address(0));
    }

    function testCantCreatePairThatAlreadyExists() public createInitialPair(address(weth), address(usdc)) {
        vm.expectRevert(CrypticFlowFactory.CrypticFlowFactory__PairAlreadyExists.selector);
        factory.createPair(address(weth), address(usdc));
    }

    function testCantCreatePairThatAlreadyExistsReversed() public createInitialPair(address(weth), address(usdc)) {
        vm.expectRevert(CrypticFlowFactory.CrypticFlowFactory__PairAlreadyExists.selector);
        factory.createPair(address(usdc), address(weth));
    }

    function testCreatePairAndAddLiquidity() public createInitialPair(address(weth), address(usdc)) {
        vm.startPrank(BOB);
        weth.transfer(initialPair, WETH_INITIAL_LIQUIDITY);
        usdc.transfer(initialPair, USDC_INITIAL_LIQUIDITY);
        vm.stopPrank();

        ICrypticFlowPair(initialPair).mint(BOB);

        uint256 expectedBobWethBalance = STARTING_WETH_BALANCE - WETH_INITIAL_LIQUIDITY;
        uint256 expectedBobUsdcBalance = STARTING_USDC_BALANCE - USDC_INITIAL_LIQUIDITY;
        uint256 expectedBobLpTokens = ICrypticFlowPair(initialPair).totalSupply() - 1000;

        assertEq(weth.balanceOf(BOB), expectedBobWethBalance);
        assertEq(usdc.balanceOf(BOB), expectedBobUsdcBalance);
        assertEq(ICrypticFlowPair(initialPair).balanceOf(BOB), expectedBobLpTokens);
    }

    function testCreatePairAndRemoveLiquidity() public createInitialPair(address(weth), address(usdc)) {
        vm.startPrank(BOB);
        weth.transfer(initialPair, WETH_INITIAL_LIQUIDITY);
        usdc.transfer(initialPair, USDC_INITIAL_LIQUIDITY);
        vm.stopPrank();

        ICrypticFlowPair(initialPair).mint(BOB);

        uint256 bobLpToBurn = ICrypticFlowPair(initialPair).balanceOf(BOB);
        vm.prank(BOB);
        ICrypticFlowPair(initialPair).transfer(initialPair, bobLpToBurn);

        ICrypticFlowPair(initialPair).burn(BOB);

        (uint256 remainingReservesWeth, uint256 remainingReservesUsdc) = ICrypticFlowPair(initialPair).getReserves();

        uint256 expectedBobWethBalance = STARTING_WETH_BALANCE - remainingReservesWeth;
        uint256 expectedBobUsdcBalance = STARTING_USDC_BALANCE - remainingReservesUsdc;
        uint256 expectedBobLpBalance = 0;

        assertEq(weth.balanceOf(BOB), expectedBobWethBalance);
        assertEq(usdc.balanceOf(BOB), expectedBobUsdcBalance);
        assertEq(ICrypticFlowPair(initialPair).balanceOf(BOB), expectedBobLpBalance);
    }

    /*//////////////////////////////////////////////////////////////
                            SET FEE TO TESTS
    //////////////////////////////////////////////////////////////*/
    function testSetFeeTo() public {
        factory.setFeeTo(FEES);
        assert(factory.feeTo() == FEES);
    }

    function testSetFeeToOnlyFeeToSetterPermitted() public {
        vm.prank(BOB);
        vm.expectRevert(CrypticFlowFactory.CrypticFlowFactory__OnlyFeeToSetterIsPermitted.selector);
        factory.setFeeTo(BOB);
    }

    /*//////////////////////////////////////////////////////////////
                        SET FEE TO SETTER TESTS
    //////////////////////////////////////////////////////////////*/
    function testSetFeeToSetter() public {
        factory.setFeeToSetter(FEES);
        assert(factory.feeToSetter() == FEES);
    }

    function testSetFeeToSetterOnlyFeeToSetterPermitted() public {
        vm.prank(BOB);
        vm.expectRevert(CrypticFlowFactory.CrypticFlowFactory__OnlyFeeToSetterIsPermitted.selector);
        factory.setFeeToSetter(BOB);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/
    function testGetLengthOfAllPairs() public createInitialPair(address(weth), address(usdc)) {
        uint256 allPairsLength = factory.getAllPairsLength();
        uint256 expectedLength = 1;

        assertEq(allPairsLength, expectedLength);
    }
}
