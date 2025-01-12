// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentalizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {MockV3Aggregator} from "../test/mock/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/mock/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetWorkConfig {
        address wethPriceFeeds;
        address wbtcPriceFeeds;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    NetWorkConfig public activeNetWorkConfig;
    uint8 private constant DECIMALS = 8;
    int256 private constant ETH_INITALANSWER = 4000e8;
    int256 private constant BTC_INITALANSWER = 97999e8;
    uint256 private constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11_155_111) {
            activeNetWorkConfig = getSepoliaNetWorkConfig();
        } else {
            activeNetWorkConfig = getOrCreatedAnvilNetWorkConfig();
        }
    }

    function getSepoliaNetWorkConfig() internal view returns (NetWorkConfig memory sepoliaNetWorkConfig) {
        sepoliaNetWorkConfig = NetWorkConfig({
            wethPriceFeeds: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcPriceFeeds: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreatedAnvilNetWorkConfig() internal returns (NetWorkConfig memory anvilNetWorkConfig) {
        if (activeNetWorkConfig.wethPriceFeeds != address(0)) {
            return activeNetWorkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethMockV3Aggregator = new MockV3Aggregator(DECIMALS, ETH_INITALANSWER);
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);

        MockV3Aggregator btcMockV3Aggregator = new MockV3Aggregator(DECIMALS, BTC_INITALANSWER);
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8); //这个合约接口不对，都不用传参，明天看github有没有人回答

        vm.stopBroadcast();
        anvilNetWorkConfig = NetWorkConfig({
            wethPriceFeeds: address(ethMockV3Aggregator),
            wbtcPriceFeeds: address(btcMockV3Aggregator),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: ANVIL_PRIVATE_KEY
        });
    }
}
