// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// Invariants:
// protocol must never be insolvent / undercollateralized
// TODO: users cant create stablecoins with a bad health factor
// TODO: a user should only be able to be liquidated if they have a bad health factor

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../../script/DeployDSC.s.sol";

import {DecentralizedStableCoin} from "../../../src/DecentalizedStableCoin.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {HelperConfig} from "../../../script/HelperConfing.s.sol";
import {ERC20Mock} from "../../mock/ERC20Mock.sol";
import {MockV3Aggregator} from "../../mock/MockV3Aggregator.sol";
import {StopOnRevertHandler} from "./StopOnRevertHandler.t.sol";

contract StopOnRevertInvariants is StdInvariant, Test {
    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;
    HelperConfig public config;

    address public weth;
    address public wbtc;
    address public wethPricefeeds;
    address public wbtcPricefeeds;
    StopOnRevertHandler handler;

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (wethPricefeeds, wbtcPricefeeds, weth, wbtc, ) = config
            .activeNetWorkConfig();
        handler = new StopOnRevertHandler(dsce, dsc);
        targetContract(address(handler));
    }

    /**
     *   永恒不变的定律：
     *                DSC的流通量一定小于质押物的美元价值：
     *                                 totalDSC<=totalWethInUSD+totalWbtcInUSD
     *                                    DSC<=Collateral
     */
    function invariant_protocolMustHaveMoreValueThatTotalSupplyDollars()
        public
        view
    {
        uint256 totalDscVal = dsc.totalSupply();

        uint256 wethAmount = ERC20Mock(weth).balanceOf(address(dsce));
        uint256 wbtcAmount = ERC20Mock(wbtc).balanceOf(address(dsce));
        uint256 wethAmountInUSD = dsce.getTokenToUsdPrice(weth, wethAmount);
        uint256 wbtcAmountInUSD = dsce.getTokenToUsdPrice(wbtc, wbtcAmount);
        console.log("wethAmountInUSD: ", wethAmountInUSD);
        console.log("wbtcAmountInUSD: ", wbtcAmountInUSD);
        console.log("totalDSC: ", totalDscVal);

        assert(wbtcAmountInUSD + wethAmountInUSD >= totalDscVal);
    }
}
