// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDecentralizedStableCoin is Script {
    DecentralizedStableCoin private s_decentralizedStableCoin;

    function run() public returns (DecentralizedStableCoin) {
        vm.startBroadcast();
        s_decentralizedStableCoin = new DecentralizedStableCoin();
        vm.stopBroadcast();

        return s_decentralizedStableCoin;
    }
}
