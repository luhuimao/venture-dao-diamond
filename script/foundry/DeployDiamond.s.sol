// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../../contracts/Diamond.sol";
import "../../contracts/DAOFactory.sol";
import "../../contracts/facets/DiamondCutFacet.sol";
import "../../contracts/facets/DiamondLoupeFacet.sol";
import "../../contracts/facets/OwnershipFacet.sol";
import "../../contracts/facets/ConfigurationFacet.sol";
import "../../contracts/facets/MembershipFacet.sol";
import "../../contracts/facets/ProposalFacet.sol";
import "../../contracts/facets/GovernanceFacet.sol";
import "../../contracts/facets/FundingFacet.sol";
import "../../contracts/upgradeInitializers/DiamondInit.sol";

/**
 * @title DeployDiamond
 * @notice Deployment script for Diamond DAO infrastructure
 * @dev Run with: forge script script/foundry/DeployDiamond.s.sol:DeployDiamond --rpc-url <RPC> --broadcast
 */
contract DeployDiamond is Script {
    // Deployed addresses
    DAOFactory public factory;
    
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    DiamondInit public diamondInit;
    
    ConfigurationFacet public configurationFacet;
    MembershipFacet public membershipFacet;
    ProposalFacet public proposalFacet;
    GovernanceFacet public governanceFacet;
    FundingFacet public fundingFacet;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying Diamond DAO infrastructure...");
        console.log("Deployer:", deployer);
        console.log("---");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy core facets (shared across all DAOs)
        console.log("Step 1: Deploying core facets...");
        diamondCutFacet = new DiamondCutFacet();
        console.log("  DiamondCutFacet:", address(diamondCutFacet));
        
        diamondLoupeFacet = new DiamondLoupeFacet();
        console.log("  DiamondLoupeFacet:", address(diamondLoupeFacet));
        
        ownershipFacet = new OwnershipFacet();
        console.log("  OwnershipFacet:", address(ownershipFacet));
        
        diamondInit = new DiamondInit();
        console.log("  DiamondInit:", address(diamondInit));

        // 2. Deploy business facets (shared across all DAOs)
        console.log("\nStep 2: Deploying business facets...");
        configurationFacet = new ConfigurationFacet();
        console.log("  ConfigurationFacet:", address(configurationFacet));
        
        membershipFacet = new MembershipFacet();
        console.log("  MembershipFacet:", address(membershipFacet));
        
        proposalFacet = new ProposalFacet();
        console.log("  ProposalFacet:", address(proposalFacet));
        
        governanceFacet = new GovernanceFacet();
        console.log("  GovernanceFacet:", address(governanceFacet));
        
        fundingFacet = new FundingFacet();
        console.log("  FundingFacet:", address(fundingFacet));

        // 3. Deploy DAOFactory
        console.log("\nStep 3: Deploying DAOFactory...");
        factory = new DAOFactory();
        console.log("  DAOFactory:", address(factory));

        // 4. Set business facets in factory
        console.log("\nStep 4: Configuring DAOFactory...");
        factory.setBusinessFacets(
            address(governanceFacet),
            address(fundingFacet),
            address(membershipFacet),
            address(proposalFacet),
            address(configurationFacet)
        );
        console.log("  Business facets configured");

        vm.stopBroadcast();

        // 5. Print deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("DAOFactory:", address(factory));
        console.log("\nCore Facets:");
        console.log("  DiamondCutFacet:", address(diamondCutFacet));
        console.log("  DiamondLoupeFacet:", address(diamondLoupeFacet));
        console.log("  OwnershipFacet:", address(ownershipFacet));
        console.log("  DiamondInit:", address(diamondInit));
        console.log("\nBusiness Facets:");
        console.log("  ConfigurationFacet:", address(configurationFacet));
        console.log("  MembershipFacet:", address(membershipFacet));
        console.log("  ProposalFacet:", address(proposalFacet));
        console.log("  GovernanceFacet:", address(governanceFacet));
        console.log("  FundingFacet:", address(fundingFacet));
        console.log("========================\n");

        // 6. Save deployment info
        _saveDeployment();
    }

    function _saveDeployment() internal {
        string memory json = "deployment";
        
        vm.serializeAddress(json, "factory", address(factory));
        vm.serializeAddress(json, "diamondCutFacet", address(diamondCutFacet));
        vm.serializeAddress(json, "diamondLoupeFacet", address(diamondLoupeFacet));
        vm.serializeAddress(json, "ownershipFacet", address(ownershipFacet));
        vm.serializeAddress(json, "diamondInit", address(diamondInit));
        vm.serializeAddress(json, "configurationFacet", address(configurationFacet));
        vm.serializeAddress(json, "membershipFacet", address(membershipFacet));
        vm.serializeAddress(json, "proposalFacet", address(proposalFacet));
        vm.serializeAddress(json, "governanceFacet", address(governanceFacet));
        string memory finalJson = vm.serializeAddress(json, "fundingFacet", address(fundingFacet));
        
        vm.writeJson(finalJson, "./deployments/diamond-deployment.json");
        console.log("Deployment info saved to: ./deployments/diamond-deployment.json");
    }
}
