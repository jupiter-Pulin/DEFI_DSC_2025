// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";

import {DecentralizedStableCoin} from "../../src/DecentalizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfing.s.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";

contract TestHealthFactory is Test {
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    DeployDSC deployer;
    address wethPriceFeeds;
    address weth;
    address public user = address(1);
    uint256 private constant ERC20Amount = 12e18;
    uint256 private constant DEPOSIT_AMOUNT = 3e18;
    //DEPOSIT_AMOUNT当前的美元计算 1ETH/4000$,所以
    // 所以DEPOSIT_AMOUNT实际资产为 2e18*4000=8000e18，在除以阈值50% ==4000e18
    //需要让 (DEPOSIT_AMOUNT*50%)*精度1e18 / MINT_DSC >=1e18;
    //所以最多能造 MINT_DSC==4e18 次方的DSC，但我们不打算能质押这么高，所以要把额度调成2倍
    uint256 private constant MINT_DSC = 5e18;
    event CollateralizedDeposit(
        address indexed user,
        address indexed tokenCollateralAddr,
        uint256 indexed _amount
    );

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (wethPriceFeeds, , weth, , ) = config.activeNetWorkConfig();
        ERC20Mock(weth).mint(user, ERC20Amount);
        vm.deal(user, 10 ether);
    }

    function testHealthFactory() public {
        vm.startBroadcast(user);
        ERC20Mock(weth).approve(address(dsce), 2e18);
        dsce.depositCollateralizedAndMintDSC(weth, 2e18, 1000e18);
        //2e18*4000/2=4000e18/1000e18=4e18
        uint256 actualHealthState = dsce.getHealthFactoryState(user);
        console.log("actualHealthState:  ", actualHealthState);

        uint256 expectHealthState = 4e18;
        console.log("expectHealthState:  ", expectHealthState);
        assert(expectHealthState == actualHealthState);

        vm.stopBroadcast();
    }
}
