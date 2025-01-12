///////////////////////////////////////////////////// ///////
///正常来说uint测试应该直接不写部署脚本  ///////////////////////
///而是直接测试某个功能,但因为跟着教程走的，代码写的很自信没有问题
///     这里为了省事就没有单独写测试，这个测试应该是集成测试//////
//////////////////////////////////////////////////////////////

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";

import {DecentralizedStableCoin} from "../../src/DecentalizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfing.s.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";
import {MockV3Aggregator} from "../mock/MockV3Aggregator.sol";

contract TestDeployDSC is Test {
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    DeployDSC deployer;
    address wethPriceFeeds;
    address weth;
    address public user = address(1);
    uint256 private constant ERC20Amount = 5e18;
    uint256 private constant DEPOSIT_AMOUNT = 2e18;
    uint256 private constant MINT_DSC = 4e18;
    address liquidater = makeAddr("liquidater");

    event CollateralizedDeposit(
        address indexed user,
        address indexed tokenCollateralAddr,
        uint256 indexed _amount
    );
    event MintedDSC(uint256);
    event CollateralizedReddem(
        address indexed tokenCollateralAddr,
        uint256 amountCollateral,
        address indexed tokenAddrFrom,
        address indexed tokenAddrTo
    );

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (wethPriceFeeds, , weth, , ) = config.activeNetWorkConfig();
        ERC20Mock(weth).mint(user, ERC20Amount); //必须先要有 WETH通证
        vm.deal(user, 10 ether);
        vm.deal(liquidater, 10 ether);
    }

    //////////////////////////////
    ////      pricefeeds TEST ////
    //////////////////////////////
    function testPriceFeeds() public view {
        uint256 eth_amount = 5e18;
        uint256 actualAmount = dsce.getTokenToUsdPrice(weth, eth_amount);
        uint256 expectAmount = 20000e18;
        // ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
        //4000*1e10*5e18==20000e18/e18=20000
        assert(actualAmount == expectAmount);
    }

    function testGetDebtForEthAmount() public view {
        uint256 eth_amount = 3e18;
        uint256 debtAmount = dsce.getTokenToUsdPrice(weth, eth_amount);
        uint256 actualEthAmount = dsce.getDebtForEthAmount(weth, debtAmount);
        //3e18*4000=12000e18*e18/4000e18==5e18

        assert(actualEthAmount == eth_amount);
    }

    /////////////////////////////////////////
    ////      depositCollateralized TEST ////
    ////////////////////////////////////////
    function testMoreThanZero() public {
        //dsce.depositCollateralized(weth);
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), 1 ether);
        vm.expectRevert(DSCEngine.DSCEngine__moreThanZero.selector);
        dsce.depositCollateralized(weth, 0);
        vm.stopPrank();
    }

    function testIsAllowedToken() public {
        ERC20Mock worngToken = new ERC20Mock("RAN", "RAN", user, 100e18);
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), 1 ether);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedTokenAddr.selector);
        dsce.depositCollateralized(address(worngToken), 1 ether);
        vm.stopPrank();
    }

    function testCollateralizedDepositEmitSuccess() public {
        vm.startPrank(user);

        ERC20Mock(weth).approve(address(dsce), DEPOSIT_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit CollateralizedDeposit(user, weth, DEPOSIT_AMOUNT);

        dsce.depositCollateralized(weth, DEPOSIT_AMOUNT);
        uint256 actualDepositedAmount = dsce.getcollateralDeposited(weth, user);
        assert(actualDepositedAmount == DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    modifier depositCollateralized() {
        vm.startBroadcast(user);
        ERC20Mock(weth).approve(address(dsce), DEPOSIT_AMOUNT);
        dsce.depositCollateralized(weth, DEPOSIT_AMOUNT);
        vm.stopBroadcast();
        _;
    }

    function testCandsceDepositCollateralizedWithoutMint()
        public
        depositCollateralized
    {
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    /////////////////////////////////////////
    ////      mint TEST                  ////
    ////////////////////////////////////////
    function testMoreThanZeroForMint() public {
        vm.startBroadcast(user);
        ERC20Mock(weth).approve(address(dsce), DEPOSIT_AMOUNT);
        dsce.depositCollateralized(weth, DEPOSIT_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__moreThanZero.selector);
        dsce.mintDSC(0);

        vm.stopBroadcast();
    }

    //这段代码在partirrick中又搞了一个mock合约，详细代码请查看：https://github.com/Cyfrin/foundry-defi-stablecoin-cu/blob/main/test/mocks/MockFailedMintDSC.sol
    // function testDscMintedIsFailed() public {
    //     vm.startBroadcast(user);
    //     vm.expectRevert(DSCEngine.DSCEngine__HealthFactoryIsLessThan1.selector);
    //     dsce.mintDSC(DEPOSIT_AMOUNT);
    //     vm.stopBroadcast();
    // }
    function testIfMintedAmountBreakeHealtyFactor() public {
        //(ETH$ *50%)  / DSCMinted

        vm.startBroadcast(user);
        ERC20Mock(weth).approve(address(dsce), 2e18);
        dsce.depositCollateralized(weth, 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__HealthFactoryIsLessThan1.selector
            )
        );
        dsce.mintDSC(4000e18);
        vm.stopBroadcast();
    }

    function testMintDscCanEmitSuccess() public {
        vm.startBroadcast(user);
        ERC20Mock(weth).approve(address(dsce), 2e18);
        dsce.depositCollateralized(weth, 2e18);
        vm.expectEmit(false, false, false, true);
        emit MintedDSC(3e18);
        dsce.mintDSC(3e18);
        vm.stopBroadcast();
    }

    function testCanMintDsc() public {
        vm.startBroadcast(user);
        ERC20Mock(weth).approve(address(dsce), 2e18);
        dsce.depositCollateralized(weth, 2e18);
        dsce.mintDSC(3e18);
        uint256 userBalance = dsc.balanceOf(user);
        uint256 userMintedDsc = dsce.getUserMintedDSC(user);
        assertEq(userBalance, userMintedDsc);
        assertEq(userBalance, 3e18);
    }

    /////////////////////////////////////////////
    ////  depositCollateralizedAndMintDSC TEST //
    ////                                     ////
    /////////////////////////////////////////////

    modifier depositCollateralizedAndMintDSC() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), 2e18);
        dsce.depositCollateralizedAndMintDSC(weth, 2e18, 3000e18);
        _;
    }

    function testCanDepositeAndMintDsc()
        public
        depositCollateralizedAndMintDSC
    {
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 3000e18);
    }

    /////////////////////////////////////////////
    ////           burn          TEST          //
    /////////////////////////////////////////////
    function testCantBurnMoreThanUserHas() public {
        vm.prank(user);
        vm.expectRevert();
        dsce.burnDsc(1);
    }

    function testBurnMoreThanZero() public depositCollateralizedAndMintDSC {
        vm.expectRevert(DSCEngine.DSCEngine__moreThanZero.selector);
        dsce.burnDsc(0);
    }

    function testBurnUserMintedMapping()
        public
        depositCollateralizedAndMintDSC
    {
        //aprove:在IERC20时，需要争得IERC20 同意，而在dsc中，则需要争得dsc的approve
        dsc.approve(address(dsce), 1e18);

        dsce.burnDsc(1e18);
        uint256 actualValue = dsce.getUserMintedDSC(user);
        uint256 expectValue = dsc.balanceOf(user);

        assertEq(expectValue, actualValue);
    }

    /////////////////////////////////////////////
    //       redeemCollateralized    TEST      //
    /////////////////////////////////////////////
    function testRedeemMoreThanZero() public depositCollateralizedAndMintDSC {
        vm.expectRevert(DSCEngine.DSCEngine__moreThanZero.selector);
        dsce.redeemCollateralized(weth, 0);
    }

    //我需要先burn掉，否则如果先赎回在回滚，系统的健康系数为0，不会允许赎回，会回滚报错DSCEngine__HealthFactoryIsLessThan1;
    //或者我不mint而是直接质押，看是否能赎回；
    function testCanRedeemCollateral() public depositCollateralized {
        //这两者的代码都可以用！！！！！
        // vm.startBroadcast(user);
        // dsce.redeemCollateralized(weth, DEPOSIT_AMOUNT);
        // uint256 collateralAmount = dsce.getcollateralDeposited(weth);       //
        // assertEq(collateralAmount, 0);                                     //
        // vm.stopBroadcast();                                                //
        /////////////////////////////////////////////////////////////////////////
        vm.startPrank(user);
        uint256 balanceBeforeRedeem = ERC20Mock(weth).balanceOf(user);
        dsce.redeemCollateralized(weth, 2e18);
        uint256 balanceAfterRedeem = ERC20Mock(weth).balanceOf(user);
        vm.stopPrank();

        uint256 redeemedAmount = balanceAfterRedeem - balanceBeforeRedeem;
        assertEq(redeemedAmount, 2e18);
    }

    function testEmitRedeemSuccess() public depositCollateralized {
        vm.startPrank(user);
        vm.expectEmit(true, false, true, true);
        emit CollateralizedReddem(weth, DEPOSIT_AMOUNT, user, user);
        dsce.redeemCollateralized(weth, DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////
    //       redeemCollateralizedAndBurnedDSC   TEST      //
    ////////////////////////////////////////////////////////
    function testCanBurnAndRedeemCollateralized() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), 2e18);
        dsce.depositCollateralizedAndMintDSC(weth, 2e18, 3000e18);
        dsc.approve(address(dsce), 3000e18);

        dsce.redeemCollateralizedAndBurnDSC(3000e18, weth, 2e18);
        uint256 userBalance = dsc.balanceOf(user); //3e18
        uint256 collateralizedVal = dsce.getcollateralDeposited(weth, user); //2e18
        console.log("collateralizedVal: ", collateralizedVal);
        console.log("userBalance:", userBalance);
        assertEq(userBalance, collateralizedVal);
    }

    ////////////////////////////////////////////////////////
    //                 healthyFactoy            TEST      //
    ////////////////////////////////////////////////////////
    function testHealthFactorCanGoBelowOne() public {
        vm.startBroadcast(user);
        ERC20Mock(weth).approve(address(dsce), 2e18);
        dsce.depositCollateralizedAndMintDSC(weth, 2e18, 1e18);
        int256 ethUsdUpdatedPrice = 3000e8;

        MockV3Aggregator(wethPriceFeeds).updateAnswer(ethUsdUpdatedPrice);

        uint256 userHealthFactor = dsce.getHealthFactoryState(user);
        // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalDscMinted) =
        // 0.9
        assert(userHealthFactor == 3e21);
    }

    ///////////////////////
    // Liquidation Tests //
    ///////////////////////
    function testLiquidationMoreThanZero() public {
        vm.expectRevert(DSCEngine.DSCEngine__moreThanZero.selector);
        dsce.liquidate(user, weth, 0);
    }

    function testLiquidateIsAllowedToken()
        public
        depositCollateralizedAndMintDSC
    {
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedTokenAddr.selector);
        dsce.liquidate(user, wethPriceFeeds, 1e18);
    }

    function testHealthfactoryIsOK() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), 2e18);
        dsce.depositCollateralizedAndMintDSC(weth, 2e18, 3e18);
        uint256 healthFactor = dsce.getHealthFactoryState(user);
        console.log("Health Factor:", healthFactor);
        vm.stopPrank();

        vm.startPrank(liquidater);
        ERC20Mock(weth).mint(liquidater, 2e18);
        ERC20Mock(weth).approve(address(dsce), 2e18);
        dsce.depositCollateralizedAndMintDSC(weth, 2e18, 3e18);
        dsc.approve(address(dsce), 3e18);
        //如果不模拟liquidater，直接清算自己，也是没有问题的。

        vm.expectRevert(
            abi.encodeWithSelector(
                DSCEngine.DSCEngine__HealthFactoryIsOK.selector,
                healthFactor
            )
        );

        dsce.liquidate(user, weth, 3e18);
        vm.stopPrank();
    }

    modifier liquidate() {
        vm.startPrank(liquidater);
        ERC20Mock(weth).mint(liquidater, 9 ether);
        ERC20Mock(weth).approve(address(dsce), 9 ether);
        dsce.depositCollateralizedAndMintDSC(weth, 9 ether, 2000e18);

        vm.stopPrank();
        _;
    }

    function testHealthFactoryIsNotImproved() public liquidate {
        //setUp
        uint256 dabtToCover = 100e18;

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), 2e18);
        dsce.depositCollateralizedAndMintDSC(weth, 2e18, 2000e18); //4000e18/2000e18==2 =>healthyFactory
        vm.stopPrank();
        int256 updatePriceFeeds = 100e8;
        MockV3Aggregator(wethPriceFeeds).updateAnswer(updatePriceFeeds);
        //action
        vm.startPrank(liquidater);
        dsc.approve(address(dsce), dabtToCover);
        vm.expectRevert(
            DSCEngine.DSCEngine__HealthFactoryIsNotImproved.selector
        );
        dsce.liquidate(user, weth, dabtToCover);
        vm.stopPrank();
    }

    function testLiquidateReward()
        public
        depositCollateralizedAndMintDSC
        liquidate
    {
        vm.startPrank(liquidater);
        uint256 actualtVal = dsce.getliquidateReward(weth, 3000e18);
        //3000e18$/4000e18$*e18=0.75e18+0.075e18=0.825e18=8.25e17
        uint256 expectVal = 8.25e17;
        assertEq(actualtVal, expectVal);
    }

    function testLiquidateCanWork() public liquidate {
        // setUp
        uint256 amountCollateral = 2e18;
        //1e18*4000e18/2=2000e18*e18/x  > e18 => 2000e18/x > 1 ==> x <2000e18
        uint256 mintDsc = 1000e18;

        int256 updateEthPrice = 1000e8; //1 eth ==1000$
        console.log(
            "now the liqu state: ",
            ERC20Mock(weth).balanceOf(liquidater)
        );

        //action
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral); //deposite 1 ETH
        dsce.depositCollateralizedAndMintDSC(weth, amountCollateral, mintDsc);
        //uint256 healthSTATE = dsce.getHealthFactoryState(user);
        //console.log("health: ", healthSTATE);
        vm.stopPrank();
        MockV3Aggregator(wethPriceFeeds).updateAnswer(updateEthPrice);

        vm.startPrank(liquidater);
        dsc.approve(address(dsce), 2000e18);
        dsce.liquidate(user, weth, mintDsc);
        //console.log("health:  ", dsce.getHealthFactoryState(user));
        vm.stopPrank();

        // //assert
        vm.startPrank(user);
        uint256 actualUserVal = dsce.getUserMintedDSC(user);
        uint256 userBalance = dsce.getcollateralDeposited(weth, user);
        assertEq(actualUserVal, 0);
        assertEq(userBalance, 0.9 ether);

        uint256 actualLiquidaterVal = dsc.balanceOf(liquidater);
        uint256 expectLiquidaterVal = 2000e18 - 1000e18;
        assertEq(actualLiquidaterVal, expectLiquidaterVal);

        //check redeem of 清算者
        uint256 liqidaterEthAmount = ERC20Mock(weth).balanceOf(liquidater);
        uint256 expectAmount = dsce.getliquidateReward(weth, mintDsc);

        assertEq(liqidaterEthAmount, expectAmount);
    }
}
