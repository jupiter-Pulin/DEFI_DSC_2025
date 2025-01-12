// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Test} from "forge-std/Test.sol";
// import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol"; Updated mock location
import {ERC20Mock} from "../../mock/ERC20Mock.sol";

import {MockV3Aggregator} from "../../mock/MockV3Aggregator.sol";
import {DSCEngine, AggregatorV3Interface} from "../../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../../src/DecentalizedStableCoin.sol";
import {console} from "forge-std/console.sol";

contract StopOnRevertHandler is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Deployed contracts to interact with
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;
    ERC20Mock public weth;
    ERC20Mock public wbtc;
    // Ghost Variables
    uint96 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;
        address[] memory collateralTokens = dscEngine.getCollateralTokenAddr();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        // ethUsdPriceFeed = MockV3Aggregator(
        //     dscEngine.getCollateralTokenPriceFeed(address(weth))
        // );
        // btcUsdPriceFeed = MockV3Aggregator(
        //     dscEngine.getCollateralTokenPriceFeed(address(wbtc))
        // );
    }

    // FUNCTOINS TO INTERACT WITH

    ///////////////
    // DSCEngine //
    ///////////////
    function mintAndDepositCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        // must be more than 0
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateralized(address(collateral), amountCollateral);
        vm.stopPrank();
    }

    function redeemCollateral(
        uint256 collateralSeed,
        uint256 amountCollateral
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateral = dscEngine.getcollateralDeposited(
            address(collateral),
            msg.sender
        );

        amountCollateral = bound(amountCollateral, 0, maxCollateral);
        //vm.prank(msg.sender);
        if (amountCollateral == 0) {
            return;
        }
        vm.prank(msg.sender);
        dscEngine.redeemCollateralized(address(collateral), amountCollateral);
    }

    function burnDsc(uint256 amountDsc) public {
        // Must burn more than 0
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        if (amountDsc == 0) {
            return;
        }
        console.log("amountDSC:  ", amountDsc);
        vm.startPrank(msg.sender);
        dsc.approve(address(dscEngine), amountDsc);
        dscEngine.burnDsc(amountDsc);
        vm.stopPrank();
    }

    /**
 * 
 * 
        //1.find balanceof user   ,if balanceof ==0 => return

        //2.check health factory,if>min_heal =>return
        //3.liquidate debtDsc (1,getUserMintedDSC)
 */
    function liquidate(
        uint256 collateralSeeds,
        address user,
        uint256 debtDsc
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeeds);

        uint256 maxDebtDsc = dscEngine.getUserMintedDSC(user);
        if (maxDebtDsc == 0) {
            return;
        }
        uint256 healthFactory = dscEngine.getHealthFactoryState(user);
        if (healthFactory > dscEngine.getMinHealthFactory()) {
            return;
        }
        debtDsc = bound(debtDsc, 1, maxDebtDsc);
        vm.startPrank(msg.sender);
        if (dsc.balanceOf(msg.sender) < debtDsc) {
            return;
        }
        dsc.approve(address(dscEngine), debtDsc);
        dscEngine.liquidate(user, address(collateral), debtDsc);
    }

    /////////////////////////////
    // DecentralizedStableCoin //
    /////////////////////////////

    //正常来说erc20mock合约的transfer也要去测试的
    //并不是去测试能否转移给dsce，而是看dsc代币能否正常在市面上流通
    function transferDsc(uint256 amountDsc, address to) public {
        if (to == address(0)) {
            return;
        }
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        vm.prank(msg.sender);
        dsc.transfer(to, amountDsc);
    }

    /////////////////////////////
    // Aggregator //
    /////////////////////////////
    function aggregaterPricefeeds(
        uint96 answer,
        uint256 collateralSeeds
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeeds);
        MockV3Aggregator priceFeeds = MockV3Aggregator(
            dscEngine.getCollateralTokenPriceFeed(address(collateral))
        );
        int256 updateAnswer = int256(uint256(answer));
        priceFeeds.updateAnswer(updateAnswer);
    }

    function _getCollateralFromSeed(
        uint256 collateralSeed
    ) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
