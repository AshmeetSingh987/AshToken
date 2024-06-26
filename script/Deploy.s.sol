// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../contracts/TokenVesting.sol";
import "../contracts/AshToken.sol";
import "./DeployHelpers.s.sol";

contract DeployScript is ScaffoldETHDeploy {
    error InvalidPrivateKey(string);

    function run() external {
        uint256 deployerPrivateKey = setupLocalhostEnv();
        if (deployerPrivateKey == 0) {
            revert InvalidPrivateKey(
                "You don't have a deployer account. Make sure you have set DEPLOYER_PRIVATE_KEY in .env or use `yarn generate` to generate a new random account"
            );
        }
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the Qoodo token contract
        AshToken ashToken = new AshToken();
        console.logString(
            string.concat(
                "Ash token deployed at: ",
                vm.toString(address(ashToken))
            )
        );

        // Deploy the TokenVesting contract, passing the Qoodo token address
        TokenVesting tokenVesting = new TokenVesting(
            address(ashToken),
            vm.addr(deployerPrivateKey)
        );
        console.logString(
            string.concat(
                "TokenVesting deployed at: ",
                vm.toString(address(tokenVesting))
            )
        );

        vm.stopBroadcast();

        /**
         * This function generates the file containing the contracts Abi definitions.
         * These definitions are used to derive the types needed in the custom scaffold-eth hooks, for example.
         * This function should be called last.
         */
        exportDeployments();
    }

    function test() public {}
}
