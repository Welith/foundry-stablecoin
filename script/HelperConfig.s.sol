// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

/**
 * @title HelperConfig
 * @author Boris Kolev
 * @notice This script is used to initialize the configuration of the DEFI protocol.
 * @notice Currently, it supports two configurations: Sepolia and Anvil.
 */
contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    NetworkConfig public activeConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 40000e8;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public constant SEPOLIA_ETH_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant SEPOLIA_BTC_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address public constant SEPOLIA_WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address public constant SEPOLIA_WBTC = 0x92f3B59a79bFf5dc60c0d59eA13a44D082B2bdFC;

    constructor() {
        if (block.chainid == 11155111) {
            activeConfig = getSepoliaEthConfig();
        } else {
            activeConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: SEPOLIA_ETH_PRICE_FEED,
            wbtcUsdPriceFeed: SEPOLIA_BTC_PRICE_FEED,
            weth: SEPOLIA_WETH,
            wbtc: SEPOLIA_WBTC,
            deployerKey: vm.envUint("DEPLOYER_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeConfig.wethUsdPriceFeed != address(0)) {
            return activeConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethMockPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock weth = new ERC20Mock("Wrapped Ether", "WETH", msg.sender, 1000e18);

        MockV3Aggregator btcMockPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtc = new ERC20Mock("Wrapped Bitcoin", "WBTC", msg.sender, 2000e18);
        vm.stopBroadcast();

        return NetworkConfig({
            wethUsdPriceFeed: address(ethMockPriceFeed),
            wbtcUsdPriceFeed: address(btcMockPriceFeed),
            weth: address(weth),
            wbtc: address(wbtc),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}
