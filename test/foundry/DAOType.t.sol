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
import "../../contracts/libraries/LibDAOStorage.sol";

/**
 * @title DAOTypeTest
 * @notice Comprehensive test suite for all DAO types (Flex, Vintage, Collective)
 * @dev Tests complete business workflows for each DAO type
 */
contract DAOTypeTest is Test {
    DAOFactory public factory;
    
    // Facets
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
    address public dave = address(0x4);
    address public eve = address(0x5);

    function setUp() public {
        // Deploy business facets
        configurationFacet = new ConfigurationFacet();
        membershipFacet = new MembershipFacet();
        proposalFacet = new ProposalFacet();
        governanceFacet = new GovernanceFacet();
        fundingFacet = new FundingFacet();

        // Deploy factory
        factory = new DAOFactory();
        
        // Set business facets
        factory.setBusinessFacets(
            address(governanceFacet),
            address(fundingFacet),
            address(membershipFacet),
            address(proposalFacet),
            address(configurationFacet)
        );
        
        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(dave, 100 ether);
        vm.deal(eve, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        FLEX DAO TESTS
    //////////////////////////////////////////////////////////////*/

    function testFlexDAO_CompleteWorkflow() public {
        // 1. Create Flex DAO
        address payable flexDAO = _createFlexDAO();
        
        // 2. Verify DAO type
        ConfigurationFacet config = ConfigurationFacet(flexDAO);
        assertEq(config.daoType(), "flex", "Should be flex DAO");
        
        // 3. Add members with different shares
        MembershipFacet membership = MembershipFacet(flexDAO);
        membership.registerMember(charlie, 25);
        membership.registerMember(dave, 15);
        
        // 4. Add stewards (need one to sponsor)
        membership.addSteward(owner);
        membership.addSteward(alice);
        membership.addSteward(bob);
        
        // 5. Submit proposal
        membership.whitelistProposer(owner);
        ProposalFacet proposals = ProposalFacet(flexDAO);
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        
        // 6. Sponsor proposal
        proposals.sponsorProposal(proposalId);
        
        // 7. Vote on proposal (weighted by shares)
        GovernanceFacet governance = GovernanceFacet(flexDAO);
        vm.prank(alice);
        governance.submitVote(proposalId, 1); // Yes, 50 shares
        
        vm.prank(bob);
        governance.submitVote(proposalId, 1); // Yes, 50 shares
        
        vm.prank(charlie);
        governance.submitVote(proposalId, 0); // No, 25 shares
        
        // 8. Process voting result
        vm.warp(block.timestamp + 8 days);
        governance.processVotingResult(proposalId);
        
        // 9. Verify result (should pass: 100 yes vs 25 no)
        (uint256 yes, uint256 no, ) = governance.getVotingResult(proposalId);
        assertTrue(yes > no, "Proposal should pass");
        assertEq(yes, 100, "Should have 100 yes votes");
        assertEq(no, 25, "Should have 25 no votes");
        
        emit log_string("Flex DAO Complete Workflow: PASSED");
    }

    function testFlexDAO_FundingWorkflow() public {
        address payable flexDAO = _createFlexDAO();
        
        // 1. Setup funding
        MembershipFacet membership = MembershipFacet(flexDAO);
        membership.whitelistProposer(owner);
        membership.addSteward(owner);
        membership.whitelistInvestor(alice);
        membership.whitelistInvestor(bob);
        
        ProposalFacet proposals = ProposalFacet(flexDAO);
        FundingFacet funding = FundingFacet(flexDAO);
        
        // 2. Create funding proposal
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        proposals.sponsorProposal(proposalId);
        
        // 3. Multiple investors deposit
        vm.prank(alice);
        funding.deposit{value: 5 ether}(proposalId);
        
        vm.prank(bob);
        funding.deposit{value: 3 ether}(proposalId);
        
        // 4. Verify contributions
        assertEq(funding.getContribution(proposalId, alice), 5 ether);
        assertEq(funding.getContribution(proposalId, bob), 3 ether);
        
        (uint256 totalRaised, , ) = funding.getFundingInfo(proposalId);
        assertEq(totalRaised, 8 ether, "Should have 8 ETH raised");
        
        emit log_string("Flex DAO Funding Workflow: PASSED");
    }

    function testFlexDAO_MembershipProgression() public {
        address payable flexDAO = _createFlexDAO();
        MembershipFacet membership = MembershipFacet(flexDAO);
        
        // 1. Regular member joins
        membership.registerMember(charlie, 10);
        assertTrue(membership.isMember(charlie));
        assertFalse(membership.isSteward(charlie));
        
        // 2. Member becomes steward
        membership.addSteward(charlie);
        assertTrue(membership.isSteward(charlie));
        
        // 3. Verify shares are preserved
        assertEq(membership.getMemberShares(charlie), 10);
        
        // 4. Member removed
        membership.removeMember(charlie);
        assertFalse(membership.isMember(charlie));
        assertFalse(membership.isSteward(charlie));
        
        emit log_string("Flex DAO Membership Progression: PASSED");
    }

    /*//////////////////////////////////////////////////////////////
                        VINTAGE DAO TESTS
    //////////////////////////////////////////////////////////////*/

    function testVintageDAO_CompleteWorkflow() public {
        // 1. Create Vintage DAO (traditional VC model)
        address payable vintageDAO = _createVintageDAO();
        
        // 2. Verify DAO type
        ConfigurationFacet config = ConfigurationFacet(vintageDAO);
        assertEq(config.daoType(), "vintage", "Should be vintage DAO");
        
        // 3. GPs (General Partners) = Stewards
        MembershipFacet membership = MembershipFacet(vintageDAO);
        membership.addSteward(alice); // GP
        membership.addSteward(bob);   // GP
        
        // 4. LPs (Limited Partners) = Investors
        membership.whitelistInvestor(charlie);
        membership.whitelistInvestor(dave);
        membership.whitelistInvestor(eve);
        
        // 5. Investment proposal (GPs can propose and sponsor)
        membership.whitelistProposer(alice); // GP can propose
        membership.whitelistProposer(bob);
        ProposalFacet proposals = ProposalFacet(vintageDAO);
        vm.prank(alice); // Alice submits as GP
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        
        // 6. Sponsor (GP approval - need to be steward)
        vm.prank(alice); // Alice is GP/steward
        proposals.sponsorProposal(proposalId);
        
        // 7. LP funding
        FundingFacet funding = FundingFacet(vintageDAO);
        
        vm.prank(charlie);
        funding.deposit{value: 10 ether}(proposalId);
        
        vm.prank(dave);
        funding.deposit{value: 15 ether}(proposalId);
        
        vm.prank(eve);
        funding.deposit{value: 5 ether}(proposalId);
        
        // 8. Verify total raise
        (uint256 totalRaised, , ) = funding.getFundingInfo(proposalId);
        assertEq(totalRaised, 30 ether, "Should have 30 ETH from LPs");
        
        // 9. GP voting
        GovernanceFacet governance = GovernanceFacet(vintageDAO);
        vm.prank(alice);
        governance.submitVote(proposalId, 1); // GP approves
        
        vm.prank(bob);
        governance.submitVote(proposalId, 1); // GP approves
        
        // 10. Process and verify
        vm.warp(block.timestamp + 8 days);
        governance.processVotingResult(proposalId);
        
        (uint256 yes, uint256 no, ) = governance.getVotingResult(proposalId);
        assertTrue(yes > no, "Investment should be approved by GPs");
        
        emit log_string("Vintage DAO Complete Workflow: PASSED");
    }

    function testVintageDAO_GPControl() public {
        address payable vintageDAO = _createVintageDAO();
        MembershipFacet membership = MembershipFacet(vintageDAO);
        
        // 1. Add GPs
        membership.addSteward(alice);
        membership.addSteward(bob);
        
        // 2. GPs have voting power
        assertTrue(membership.isSteward(alice));
        assertTrue(membership.isSteward(bob));
        
        // 3. LPs don't control governance
        membership.whitelistInvestor(charlie);
        assertFalse(membership.isSteward(charlie));
        assertTrue(membership.isInvestorWhitelisted(charlie));
        
        emit log_string("Vintage DAO GP Control: PASSED");
    }

    function testVintageDAO_MultiRoundFunding() public {
        address payable vintageDAO = _createVintageDAO();
        MembershipFacet membership = MembershipFacet(vintageDAO);
        membership.whitelistProposer(owner);
        membership.addSteward(owner);
        membership.whitelistInvestor(alice);
        membership.whitelistInvestor(bob);
        
        ProposalFacet proposals = ProposalFacet(vintageDAO);
        FundingFacet funding = FundingFacet(vintageDAO);
        
        // Round 1
        bytes32 round1 = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        proposals.sponsorProposal(round1);
        
        vm.prank(alice);
        funding.deposit{value: 10 ether}(round1);
        
        // Round 2
        bytes32 round2 = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        proposals.sponsorProposal(round2);
        
        vm.prank(bob);
        funding.deposit{value: 20 ether}(round2);
        
        // Verify separate rounds
        (uint256 total1, , ) = funding.getFundingInfo(round1);
        (uint256 total2, , ) = funding.getFundingInfo(round2);
        
        assertEq(total1, 10 ether);
        assertEq(total2, 20 ether);
        
        emit log_string("Vintage DAO Multi-Round Funding: PASSED");
    }

    /*//////////////////////////////////////////////////////////////
                        COLLECTIVE DAO TESTS
    //////////////////////////////////////////////////////////////*/

    function testCollectiveDAO_CompleteWorkflow() public {
        // 1. Create Collective DAO (equal participation)
        address payable collectiveDAO = _createCollectiveDAO();
        
        // 2. Verify DAO type
        ConfigurationFacet config = ConfigurationFacet(collectiveDAO);
        assertEq(config.daoType(), "collective", "Should be collective DAO");
        
        // 3. Add members (all equal)
        MembershipFacet membership = MembershipFacet(collectiveDAO);
        membership.registerMember(charlie, 1); // Equal shares
        membership.registerMember(dave, 1);
        membership.registerMember(eve, 1);
        
        // 4. Everyone can propose and sponsor
        membership.whitelistProposer(alice);
        membership.whitelistProposer(bob);
        membership.whitelistProposer(charlie);
        membership.addSteward(alice); // Need stewards to sponsor
        membership.addSteward(bob);
        
        // 5. Community proposal
        ProposalFacet proposals = ProposalFacet(collectiveDAO);
        vm.prank(charlie);
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        
        // 6. Sponsor (need to be steward)
        vm.prank(alice); // Alice is steward
        proposals.sponsorProposal(proposalId);
        
        // 7. Democratic voting (1 person = 1 vote)
        GovernanceFacet governance = GovernanceFacet(collectiveDAO);
        
        vm.prank(alice);
        governance.submitVote(proposalId, 1); // Yes
        
        vm.prank(bob);
        governance.submitVote(proposalId, 1); // Yes
        
        vm.prank(charlie);
        governance.submitVote(proposalId, 1); // Yes
        
        vm.prank(dave);
        governance.submitVote(proposalId, 0); // No
        
        vm.prank(eve);
        governance.submitVote(proposalId, 0); // No
        
        // 8. Process result
        vm.warp(block.timestamp + 8 days);
        governance.processVotingResult(proposalId);
        
        // 9. Verify (3 yes vs 2 no, with equal weight)
        (uint256 yes, uint256 no, ) = governance.getVotingResult(proposalId);
        assertTrue(yes > no, "Majority should pass");
        assertEq(yes, 3, "Should have 3 yes votes (equal weight)");
        assertEq(no, 2, "Should have 2 no votes (equal weight)");
        
        emit log_string("Collective DAO Complete Workflow: PASSED");
    }

    function testCollectiveDAO_EqualParticipation() public {
        address payable collectiveDAO = _createCollectiveDAO();
        MembershipFacet membership = MembershipFacet(collectiveDAO);
        
        // 1. All members have equal shares
        membership.registerMember(charlie, 1);
        membership.registerMember(dave, 1);
        membership.registerMember(eve, 1);
        
        assertEq(membership.getMemberShares(alice), 1);
        assertEq(membership.getMemberShares(bob), 1);
        assertEq(membership.getMemberShares(charlie), 1);
        assertEq(membership.getMemberShares(dave), 1);
        assertEq(membership.getMemberShares(eve), 1);
        
        emit log_string("Collective DAO Equal Participation: PASSED");
    }

    function testCollectiveDAO_CommunityFunding() public {
        address payable collectiveDAO = _createCollectiveDAO();
        MembershipFacet membership = MembershipFacet(collectiveDAO);
        
        // Everyone can invest
        membership.whitelistInvestor(alice);
        membership.whitelistInvestor(bob);
        membership.whitelistInvestor(charlie);
        membership.whitelistInvestor(dave);
        membership.whitelistInvestor(eve);
        
        membership.whitelistProposer(owner);
        membership.addSteward(owner);
        
        ProposalFacet proposals = ProposalFacet(collectiveDAO);
        FundingFacet funding = FundingFacet(collectiveDAO);
        
        bytes32 proposalId = proposals.submitProposal(LibDAOStorage.ProposalType.Funding);
        proposals.sponsorProposal(proposalId);
        
        // Community members contribute
        vm.prank(alice);
        funding.deposit{value: 1 ether}(proposalId);
        
        vm.prank(bob);
        funding.deposit{value: 1 ether}(proposalId);
        
        vm.prank(charlie);
        funding.deposit{value: 1 ether}(proposalId);
        
        vm.prank(dave);
        funding.deposit{value: 1 ether}(proposalId);
        
        vm.prank(eve);
        funding.deposit{value: 1 ether}(proposalId);
        
        (uint256 totalRaised, , ) = funding.getFundingInfo(proposalId);
        assertEq(totalRaised, 5 ether, "Community raised 5 ETH together");
        
        emit log_string("Collective DAO Community Funding: PASSED");
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-DAO TYPE COMPARISONS
    //////////////////////////////////////////////////////////////*/

    function testComparison_VotingPower() public {
        // Flex: weighted by shares
        address payable flexDAO = _createFlexDAO();
        MembershipFacet flexMembership = MembershipFacet(flexDAO);
        assertEq(flexMembership.getMemberShares(alice), 50);
        assertEq(flexMembership.getMemberShares(bob), 50);
        
        // Collective: equal (1 share each)
        address payable collectiveDAO = _createCollectiveDAO();
        MembershipFacet collectiveMembership = MembershipFacet(collectiveDAO);
        assertEq(collectiveMembership.getMemberShares(alice), 1);
        assertEq(collectiveMembership.getMemberShares(bob), 1);
        
        emit log_string("Voting Power Comparison: PASSED");
    }

    function testComparison_Governance() public {
        address payable flex = _createFlexDAO();
        address payable vintage = _createVintageDAO();
        address payable collective = _createCollectiveDAO();
        
        ConfigurationFacet flexConfig = ConfigurationFacet(flex);
        ConfigurationFacet vintageConfig = ConfigurationFacet(vintage);
        ConfigurationFacet collectiveConfig = ConfigurationFacet(collective);
        
        assertEq(flexConfig.daoType(), "flex");
        assertEq(vintageConfig.daoType(), "vintage");
        assertEq(collectiveConfig.daoType(), "collective");
        
        emit log_string("Governance Model Comparison: PASSED");
    }

    /*//////////////////////////////////////////////////////////////
                        GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    function testGas_CreateFlexDAO() public {
        uint256 gasBefore = gasleft();
        _createFlexDAO();
        uint256 gasUsed = gasBefore - gasleft();
        
        emit log_named_uint("Gas: Create Flex DAO", gasUsed);
        assertTrue(gasUsed < 3000000, "Should be gas efficient");
    }

    function testGas_CreateVintageDAO() public {
        uint256 gasBefore = gasleft();
        _createVintageDAO();
        uint256 gasUsed = gasBefore - gasleft();
        
        emit log_named_uint("Gas: Create Vintage DAO", gasUsed);
        assertTrue(gasUsed < 3000000, "Should be gas efficient");
    }

    function testGas_CreateCollectiveDAO() public {
        uint256 gasBefore = gasleft();
        _createCollectiveDAO();
        uint256 gasUsed = gasBefore - gasleft();
        
        emit log_named_uint("Gas: Create Collective DAO", gasUsed);
        assertTrue(gasUsed < 3000000, "Should be gas efficient");
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createFlexDAO() internal returns (address payable) {
        address[] memory founders = new address[](2);
        founders[0] = alice;
        founders[1] = bob;

        uint256[] memory allocations = new uint256[](2);
        allocations[0] = 50; // Weighted shares
        allocations[1] = 50;

        DAOFactory.DAOConfig memory config = DAOFactory.DAOConfig({
            name: "Flex DAO",
            daoType: "flex",
            founders: founders,
            allocations: allocations,
            votingPeriod: 7 days,
            quorum: 20,
            majority: 50
        });

        return payable(factory.createDAO(config));
    }

    function _createVintageDAO() internal returns (address payable) {
        address[] memory founders = new address[](2);
        founders[0] = alice; // GP
        founders[1] = bob;   // GP

        uint256[] memory allocations = new uint256[](2);
        allocations[0] = 50; // GPs have decision power
        allocations[1] = 50;

        DAOFactory.DAOConfig memory config = DAOFactory.DAOConfig({
            name: "Vintage DAO",
            daoType: "vintage",
            founders: founders,
            allocations: allocations,
            votingPeriod: 7 days,
            quorum: 20,
            majority: 50
        });

        return payable(factory.createDAO(config));
    }

    function _createCollectiveDAO() internal returns (address payable) {
        address[] memory founders = new address[](2);
        founders[0] = alice;
        founders[1] = bob;

        uint256[] memory allocations = new uint256[](2);
        allocations[0] = 1; // Equal shares
        allocations[1] = 1;

        DAOFactory.DAOConfig memory config = DAOFactory.DAOConfig({
            name: "Collective DAO",
            daoType: "collective",
            founders: founders,
            allocations: allocations,
            votingPeriod: 7 days,
            quorum: 20,
            majority: 50
        });

        return payable(factory.createDAO(config));
    }
}
