// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../../contracts/diamond/DAOFactory.sol";

/**
 * @title CreateDAO
 * @notice Script to create a new DAO using the deployed factory
 * @dev Run with: forge script script/foundry/CreateDAO.s.sol:CreateDAO --rpc-url <RPC> --broadcast
 */
contract CreateDAO is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Load factory address from deployment file
        string memory deploymentData = vm.readFile("./deployments/diamond-deployment.json");
        address factoryAddress = vm.parseJsonAddress(deploymentData, ".factory");
        
        console.log("Creating new DAO...");
        console.log("Factory:", factoryAddress);
        console.log("Creator:", deployer);
        console.log("---");

        vm.startBroadcast(deployerPrivateKey);

        DAOFactory factory = DAOFactory(factoryAddress);

        // Prepare DAO configuration
        address[] memory founders = new address[](3);
        founders[0] = deployer;
        founders[1] = address(0x1111111111111111111111111111111111111111);
        founders[2] = address(0x2222222222222222222222222222222222222222);

        uint256[] memory allocations = new uint256[](3);
        allocations[0] = 100; // 100 shares for deployer
        allocations[1] = 50;  // 50 shares for founder 1
        allocations[2] = 50;  // 50 shares for founder 2

        DAOFactory.DAOConfig memory config = DAOFactory.DAOConfig({
            name: "My Diamond DAO",
            daoType: "flex",
            founders: founders,
            allocations: allocations
        });

        // Create DAO
        address diamond = factory.createDAO(config);

        vm.stopBroadcast();

        console.log("\n=== DAO CREATED ===");
        console.log("Diamond Address:", diamond);
        console.log("DAO Name:", config.name);
        console.log("DAO Type:", config.daoType);
        console.log("Founders:", config.founders.length);
        console.log("==================\n");

        // Save DAO address
        string memory json = "dao";
        vm.serializeAddress(json, "diamond", diamond);
        vm.serializeString(json, "name", config.name);
        string memory finalJson = vm.serializeString(json, "daoType", config.daoType);
        
        vm.writeJson(finalJson, string.concat(
            "./deployments/dao-",
            vm.toString(diamond),
            ".json"
        ));
    }
}
