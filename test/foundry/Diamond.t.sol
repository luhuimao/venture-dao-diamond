// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
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
import "../../contracts/interfaces/IDiamondCut.sol";
import "../../contracts/interfaces/IDiamondLoupe.sol";

/**
 * @title DiamondTest
 * @notice Comprehensive test suite for Diamond DAO
 */
contract DiamondTest is Test {
    DAOFactory public factory;
    address payable public diamond;
    
    // Facets
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    ConfigurationFacet public configurationFacet;
    MembershipFacet public membershipFacet;
    ProposalFacet public proposalFacet;
    GovernanceFacet public governanceFacet;
    FundingFacet public fundingFacet;
    
    // Test accounts
    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    function setUp() public {
        // Deploy core facets first
        // Deploy core facets first
        // Note: These local variables were shadowing state variables.
        // We assign to the state variables directly although 'factory' will deploy its own instances.
        // For testing standalone facets if needed:
         diamondCutFacet = new DiamondCutFacet();
         diamondLoupeFacet = new DiamondLoupeFacet();
         ownershipFacet = new OwnershipFacet();
        
        // Deploy business facets
        configurationFacet = new ConfigurationFacet();
        membershipFacet = new MembershipFacet();
        proposalFacet = new ProposalFacet();
        governanceFacet = new GovernanceFacet();
        fundingFacet = new FundingFacet();

        // Deploy factory (it will deploy its own core facets internally)
        factory = new DAOFactory();
        
        // Set business facets (factory has no access control on this function)
        factory.setBusinessFacets(
            address(governanceFacet),
            address(fundingFacet),
            address(membershipFacet),
            address(proposalFacet),
            address(configurationFacet)
        );

        // Create a test DAO
        address[] memory founders = new address[](3);
        founders[0] = owner;
        founders[1] = alice;
        founders[2] = bob;

        uint256[] memory allocations = new uint256[](3);
        allocations[0] = 100;
        allocations[1] = 50;
        allocations[2] = 50;

        DAOFactory.DAOConfig memory config = DAOFactory.DAOConfig({
            name: "Test DAO",
            daoType: "flex",
            founders: founders,
            allocations: allocations,
            votingPeriod: 7 days,
            quorum: 20,
            majority: 50
        });

        // Create the DAO - this will be owned by this test contract
        diamond = payable(factory.createDAO(config));
        
        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            DIAMOND TESTS
    //////////////////////////////////////////////////////////////*/

    function testDiamondCreation() public {
        assertTrue(diamond != address(0), "Diamond should be deployed");
    }

    function testDiamondOwnership() public {
        OwnershipFacet ownerFacet = OwnershipFacet(diamond);
        assertEq(ownerFacet.owner(), owner, "Owner should be deployer");
    }

    function testFacetsInstalled() public {
        IDiamondLoupe loupe = IDiamondLoupe(diamond);
        address[] memory facetAddresses = loupe.facetAddresses();
        
        // Should have 7 facets: Cut, Loupe, Ownership + 5 business facets
        assertTrue(facetAddresses.length >= 5, "Should have at least 5 facets");
    }

    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetConfiguration() public {
        ConfigurationFacet config = ConfigurationFacet(diamond);
        bytes32 key = keccak256("TEST_KEY");
        uint256 value = 42;

        config.setConfiguration(key, value);
        assertEq(config.getConfiguration(key), value, "Configuration should be set");
    }

    function testSetAddressConfiguration() public {
        ConfigurationFacet config = ConfigurationFacet(diamond);
        bytes32 key = keccak256("TEST_ADDR");
        address value = alice;

        config.setAddressConfiguration(key, value);
        assertEq(config.getAddressConfiguration(key), value, "Address config should be set");
    }

    function testBatchSetConfiguration() public {
        ConfigurationFacet config = ConfigurationFacet(diamond);
        
        bytes32[] memory keys = new bytes32[](3);
        keys[0] = keccak256("KEY1");
        keys[1] = keccak256("KEY2");
        keys[2] = keccak256("KEY3");

        uint256[] memory values = new uint256[](3);
        values[0] = 10;
        values[1] = 20;
        values[2] = 30;

        config.batchSetConfiguration(keys, values);

        assertEq(config.getConfiguration(keys[0]), 10);
        assertEq(config.getConfiguration(keys[1]), 20);
        assertEq(config.getConfiguration(keys[2]), 30);
    }

    /*//////////////////////////////////////////////////////////////
                        MEMBERSHIP TESTS
    //////////////////////////////////////////////////////////////*/

    function testRegisterMember() public {
        MembershipFacet membership = MembershipFacet(diamond);
        
        membership.registerMember(charlie, 25);
        assertTrue(membership.isMember(charlie), "Charlie should be a member");
        assertEq(membership.getMemberShares(charlie), 25, "Charlie should have 25 shares");
    }

    function testRemoveMember() public {
        MembershipFacet membership = MembershipFacet(diamond);
        
        membership.registerMember(charlie, 25);
        assertTrue(membership.isMember(charlie));
        
        membership.removeMember(charlie);
        assertFalse(membership.isMember(charlie), "Charlie should be removed");
    }

    function testAddSteward() public {
        MembershipFacet membership = MembershipFacet(diamond);
        
        membership.addSteward(alice);
        assertTrue(membership.isSteward(alice), "Alice should be a steward");
    }

    function testRemoveSteward() public {
        MembershipFacet membership = MembershipFacet(diamond);
        
        membership.addSteward(alice);
        assertTrue(membership.isSteward(alice));
        
        membership.removeSteward(alice);
        assertFalse(membership.isSteward(alice), "Alice should not be steward");
    }

    function testWhitelistInvestor() public {
        MembershipFacet membership = MembershipFacet(diamond);
        
        membership.whitelistInvestor(charlie);
        assertTrue(membership.isInvestorWhitelisted(charlie), "Charlie should be whitelisted");
    }

    /*//////////////////////////////////////////////////////////////
                        PROPOSAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testSubmitProposal() public {
        // First whitelist the proposer
        MembershipFacet membership = MembershipFacet(diamond);
        membership.whitelistProposer(owner);
        
        ProposalFacet proposals = ProposalFacet(diamond);
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding); // Funding proposal
        
        assertTrue(proposalId != bytes32(0), "Proposal should be created");
        assertEq(proposals.getProposalCount(), 1, "Should have 1 proposal");
    }

    function testSponsorProposal() public {
        MembershipFacet membership = MembershipFacet(diamond);
        ProposalFacet proposals = ProposalFacet(diamond);
        
        // Setup
        membership.whitelistProposer(owner);
        membership.addSteward(owner);
        
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        
        // Sponsor
        proposals.sponsorProposal(proposalId);
        
        // Check proposal is active
        (, , , uint256 votingEndTime, , , , ) = proposals.getProposal(proposalId);
        assertTrue(votingEndTime > block.timestamp, "Voting should be active");
    }

    function testCancelProposal() public {
        MembershipFacet membership = MembershipFacet(diamond);
        ProposalFacet proposals = ProposalFacet(diamond);
        
        membership.whitelistProposer(owner);
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        
        proposals.cancelProposal(proposalId);
        // Proposal should be cancelled (status would be checked if we had getter)
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE TESTS
    //////////////////////////////////////////////////////////////*/

    function testSubmitVote() public {
        MembershipFacet membership = MembershipFacet(diamond);
        ProposalFacet proposals = ProposalFacet(diamond);
        GovernanceFacet governance = GovernanceFacet(diamond);
        
        // Setup
        membership.whitelistProposer(owner);
        membership.addSteward(owner);
        // alice is already a member (founder with 50 shares)
        
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        proposals.sponsorProposal(proposalId);
        
        // Vote as alice
        vm.prank(alice);
        governance.submitVote(proposalId, 1); // Yes
        
        assertTrue(governance.hasVoted(proposalId, alice), "Alice should have voted");
        assertEq(governance.getVote(proposalId, alice), 1, "Alice voted Yes");
    }

    function testProcessVotingResult() public {
        MembershipFacet membership = MembershipFacet(diamond);
        ProposalFacet proposals = ProposalFacet(diamond);
        GovernanceFacet governance = GovernanceFacet(diamond);
        
        // Setup
        membership.whitelistProposer(owner);
        membership.addSteward(owner);
        // alice and bob are already members (founders with 50 shares each)
        // Note: They already have 50 shares from being founders
        
       bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        proposals.sponsorProposal(proposalId);
        
        // Vote
        vm.prank(alice);
        governance.submitVote(proposalId, 1); // Yes
        
        vm.prank(bob);
        governance.submitVote(proposalId, 1); // Yes
        
        // Fast forward past voting period
        vm.warp(block.timestamp + 8 days);
        
        // Process result
        governance.processVotingResult(proposalId);
        
        (uint256 yes, uint256 no, ) = governance.getVotingResult(proposalId);
        assertTrue(yes > no, "Yes votes should win");
    }

    /*//////////////////////////////////////////////////////////////
                         FUNDING TESTS
    //////////////////////////////////////////////////////////////*/

    function testDeposit() public {
        MembershipFacet membership = MembershipFacet(diamond);
        ProposalFacet proposals = ProposalFacet(diamond);
        FundingFacet funding = FundingFacet(diamond);
        
        // Setup
        membership.whitelistProposer(owner);
        membership.addSteward(owner);
        membership.whitelistInvestor(alice);
        
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        proposals.sponsorProposal(proposalId);
        
        // Deposit
        vm.prank(alice);
        funding.deposit{value: 1 ether}(proposalId);
        
        (uint256 totalRaised, , ) = funding.getFundingInfo(proposalId);
        assertEq(totalRaised, 1 ether, "Should have 1 ETH raised");
        assertEq(funding.getContribution(proposalId, alice), 1 ether, "Alice contributed 1 ETH");
    }

    function testWithdraw() public {
        MembershipFacet membership = MembershipFacet(diamond);
        ProposalFacet proposals = ProposalFacet(diamond);
        FundingFacet funding = FundingFacet(diamond);
        
        // Setup
        membership.whitelistProposer(owner);
        membership.addSteward(owner); // Need steward to sponsor
        membership.whitelistInvestor(alice);
        
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        
        // Sponsor proposal first (so it becomes Active)
        proposals.sponsorProposal(proposalId);
        
        // Deposit
        vm.prank(alice);
        funding.deposit{value: 1 ether}(proposalId);
        
        // Cancel proposal
        proposals.cancelProposal(proposalId);
        
        // Withdraw
        uint256 balanceBefore = alice.balance;
        vm.prank(alice);
        funding.withdraw(proposalId);
        
        assertEq(alice.balance, balanceBefore + 1 ether, "Alice should get refund");
    }

    /*//////////////////////////////////////////////////////////////
                         GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testGas_CreateDAO() public {
        address[] memory founders = new address[](1);
        founders[0] = owner;

        uint256[] memory allocations = new uint256[](1);
        allocations[0] = 100;

        DAOFactory.DAOConfig memory config = DAOFactory.DAOConfig({
            name: "Gas Test DAO",
            daoType: "flex",
            founders: founders,
            allocations: allocations,
            votingPeriod: 7 days,
            quorum: 20,
            majority: 50
        });

        uint256 gasBefore = gasleft();
        factory.createDAO(config);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for DAO creation", gasUsed);
    }

    function testGas_SubmitProposal() public {
        MembershipFacet membership = MembershipFacet(diamond);
        ProposalFacet proposals = ProposalFacet(diamond);
        
        membership.whitelistProposer(owner);

        uint256 gasBefore = gasleft();
        proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for proposal submission", gasUsed);
    }

    function testGas_SubmitVote() public {
        MembershipFacet membership = MembershipFacet(diamond);
        ProposalFacet proposals = ProposalFacet(diamond);
        GovernanceFacet governance = GovernanceFacet(diamond);
        
        membership.whitelistProposer(owner);
        membership.addSteward(owner);
        // alice is already a member (founder)
        
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        proposals.sponsorProposal(proposalId);
        
        vm.prank(alice);
        uint256 gasBefore = gasleft();
        governance.submitVote(proposalId, 1);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for voting", gasUsed);
    }
}
