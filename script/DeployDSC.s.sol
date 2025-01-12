// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentalizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfing.s.sol";

contract DeployDSC is Script {
    address[] public priceFeeds;
    address[] public tokenAddr;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig helpconfig = new HelperConfig();
        (address wethPriceFeeds, address wbtcPriceFeeds, address weth, address wbtc, uint256 deployerKey) =
            helpconfig.activeNetWorkConfig();
        tokenAddr = [weth, wbtc];
        priceFeeds = [wethPriceFeeds, wbtcPriceFeeds];
        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine dscEngine = new DSCEngine(tokenAddr, priceFeeds, address(dsc));
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (dsc, dscEngine, helpconfig);
    }
}
