// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployCrypticFlowRouter} from "../../script/DeployCrypticFlowRouter.s.sol";
import {CrypticFlowRouter} from "../../src/CrypticFlowRouter.sol";
import {CrypticFlowFactory} from "../../src/CrypticFlowFactory.sol";
import {Handler} from "../fuzz/Handler.t.sol";

contract CrypticFlowRouterInvariants is StdInvariant, Test {
    CrypticFlowRouter router;
    CrypticFlowFactory factory;
    Handler handler;

    function setUp() public {
        DeployCrypticFlowRouter deployer = new DeployCrypticFlowRouter();
        (factory, router) = deployer.run();

        handler = new Handler(factory, router);
        targetContract(address(handler));
    }

    /*//////////////////////////////////////////////////////////////
                            INVARIANT TESTS
    //////////////////////////////////////////////////////////////*/
    function invariant_kNeverDecreases() public view {
        assert(handler.kLast() <= handler.kCurrent());
    }

    function invariant_balancesMatchReserves() public view {
        assert(handler.wethBalance() == handler.wethReserves());
        assert(handler.usdcBalance() == handler.usdcReserves());
    }
}
