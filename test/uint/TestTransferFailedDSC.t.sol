// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentalizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfing.s.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";
import {MockTransferFromFail} from "../mock/MockTransferFromFail.sol";
import {MockTransferFail} from "../mock/MockTransferFail.t.sol";
import {MockDSC} from "../mock/MockDSC.sol";
import {MockDSCE} from "../mock/MockDSCE.sol";

contract TestTransferFailedDSC is Test {
    address weth;
    address wethPriceFeeds;

    HelperConfig config;
    address public user = address(1);
    DeployDSC deployer;
    address[] public tokenAddresses;
    address[] public feedAddresses;

    function setUp() external {
        deployer = new DeployDSC();

        (, , config) = deployer.run();
        (wethPriceFeeds, , weth, , ) = config.activeNetWorkConfig();

        vm.deal(user, 3 ether);
    }

    //////////////////////////////////////////////////////////
    ////             Deposite transferFailed           ///////
    /////////////////////////////////////////////////////////

    function testDepositeTransferFailed() public {
        //arange setUp
        MockTransferFromFail mockErc20 = new MockTransferFromFail(
            "mockErc20",
            "mockdsc"
        );

        tokenAddresses = [address(mockErc20)];
        feedAddresses = [wethPriceFeeds];
        DecentralizedStableCoin mockDsc = new DecentralizedStableCoin();
        DSCEngine mockdsce = new DSCEngine(
            tokenAddresses,
            feedAddresses,
            address(mockDsc)
        );

        mockErc20.approve(address(mockdsce), 1 ether);

        //action
        vm.startPrank(user);

        uint256 amountCollateral = 2e18;

        vm.expectRevert(DSCEngine.DSCEngine__TransferfromIsfailed.selector);

        mockdsce.depositCollateralized(address(mockErc20), amountCollateral);
    }

    //////////////////////////////////////////////////////////
    ////             Redeem transferFailed           /   //////
    /////////////////////////////////////////////////////////

    function testRedeemTransferFailed() public {
        //arrange setUp
        MockTransferFail mockErc20 = new MockTransferFail(
            "mocktransferfail",
            "mockerc20"
        );
        tokenAddresses = [address(mockErc20)];
        feedAddresses = [wethPriceFeeds];
        DecentralizedStableCoin mockDsc = new DecentralizedStableCoin();
        DSCEngine mockdsce = new DSCEngine(
            tokenAddresses,
            feedAddresses,
            address(mockDsc)
        );
        mockDsc.transferOwnership(address(mockdsce));
        mockErc20.approve(address(mockdsce), 1 ether);
        //action
        vm.startPrank(user);
        mockdsce.depositCollateralizedAndMintDSC(
            address(mockErc20),
            2e18,
            1000e18
        );
        vm.expectRevert(DSCEngine.DSCEngine__TransferfromIsfailed.selector);
        mockdsce.redeemCollateralized(address(mockErc20), 2e18);
    }

    //////////////////////////////////////////////////////////
    ////             mint transferFailed               //////
    /////////////////////////////////////////////////////////

    function testMintDSCOfTransferFromFail() public {
        //arrange setUp
        MockDSC mockDsc = new MockDSC();
        MockTransferFromFail mockErc20 = new MockTransferFromFail(
            "mockErc20",
            "mockdsc"
        );
        //mockErc20.mint(user, 3 ether);  造不造无所谓，反正我改了原ERC20合约；
        tokenAddresses = [address(mockErc20)];
        feedAddresses = [wethPriceFeeds];
        MockDSCE mockDsce = new MockDSCE(
            tokenAddresses,
            feedAddresses,
            address(mockDsc)
        );
        mockDsc.transferOwnership(address(mockDsce));
        mockErc20.approve(address(mockDsce), 1 ether);
        //action
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine__mintedFailed.selector);
        mockDsce.mintDSC(1e18);
    }
}
