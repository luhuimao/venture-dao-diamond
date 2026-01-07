// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Diamond} from "./Diamond.sol";
import {DiamondCutFacet} from "./facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "./facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "./facets/OwnershipFacet.sol";
import {DiamondInit} from "./upgradeInitializers/DiamondInit.sol";
import {DAOInit} from "./upgradeInitializers/DAOInit.sol";
import {LibDiamond} from "./libraries/LibDiamond.sol";
import {LibDAOStorage} from "./libraries/LibDAOStorage.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";

/**
 * @title DAOFactory
 * @notice Factory contract for creating Venture DAOs with Diamond pattern
 * @dev One-click DAO creation with all facets pre-configured
 */
contract DAOFactory {
    event DAOCreated(
        address indexed diamond,
        address indexed creator,
        string daoType,
        string name
    );

    struct DAOConfig {
        string name;
        string daoType; // "flex", "vintage", "collective"
        address[] founders;
        uint256[] allocations;
        uint256 votingPeriod;
        uint256 quorum;
        uint256 majority;
    }

    // Facet addresses (deployed once, reused for all DAOs)
    address public immutable diamondCutFacet;
    address public immutable diamondLoupeFacet;
    address public immutable ownershipFacet;
    address public immutable diamondInit;
    address public immutable daoInit;

    // Future business facets (to be added in Phase 2)
    address public governanceFacet;
    address public fundingFacet;
    address public membershipFacet;
    address public proposalFacet;
    address public configurationFacet;

    // ========== Cached Function Selectors (Gas Optimization #1) ==========
    // Configuration Facet Selectors
    bytes4 private constant SEL_SET_CONFIG = bytes4(keccak256("setConfiguration(bytes32,uint256)"));
    bytes4 private constant SEL_GET_CONFIG = bytes4(keccak256("getConfiguration(bytes32)"));
    bytes4 private constant SEL_SET_ADDR_CONFIG = bytes4(keccak256("setAddressConfiguration(bytes32,address)"));
    bytes4 private constant SEL_GET_ADDR_CONFIG = bytes4(keccak256("getAddressConfiguration(bytes32)"));
    bytes4 private constant SEL_SET_STR_CONFIG = bytes4(keccak256("setStringConfiguration(bytes32,string)"));
    bytes4 private constant SEL_GET_STR_CONFIG = bytes4(keccak256("getStringConfiguration(bytes32)"));
    bytes4 private constant SEL_BATCH_SET_CONFIG = bytes4(keccak256("batchSetConfiguration(bytes32[],uint256[])"));
    bytes4 private constant SEL_DAO_NAME = bytes4(keccak256("daoName()"));
    bytes4 private constant SEL_DAO_TYPE = bytes4(keccak256("daoType()"));
    bytes4 private constant SEL_DAO_CREATOR = bytes4(keccak256("daoCreator()"));
    bytes4 private constant SEL_CREATED_AT = bytes4(keccak256("createdAt()"));

    // Membership Facet Selectors
    bytes4 private constant SEL_REGISTER_MEMBER = bytes4(keccak256("registerMember(address,uint256)"));
    bytes4 private constant SEL_REMOVE_MEMBER = bytes4(keccak256("removeMember(address)"));
    bytes4 private constant SEL_ADD_STEWARD = bytes4(keccak256("addSteward(address)"));
    bytes4 private constant SEL_REMOVE_STEWARD = bytes4(keccak256("removeSteward(address)"));
    bytes4 private constant SEL_UPDATE_SHARES = bytes4(keccak256("updateShares(address,uint256)"));
    bytes4 private constant SEL_WHITELIST_INVESTOR = bytes4(keccak256("whitelistInvestor(address)"));
    bytes4 private constant SEL_WHITELIST_PROPOSER = bytes4(keccak256("whitelistProposer(address)"));
    bytes4 private constant SEL_BATCH_REGISTER = bytes4(keccak256("batchRegisterMembers(address[],uint256[])"));
    bytes4 private constant SEL_IS_MEMBER = bytes4(keccak256("isMember(address)"));
    bytes4 private constant SEL_IS_STEWARD = bytes4(keccak256("isSteward(address)"));
    bytes4 private constant SEL_GET_SHARES = bytes4(keccak256("getMemberShares(address)"));
    bytes4 private constant SEL_GET_MEMBER_INFO = bytes4(keccak256("getMemberInfo(address)"));
    bytes4 private constant SEL_GET_MEMBER_COUNT = bytes4(keccak256("getMemberCount()"));
    bytes4 private constant SEL_GET_STEWARDS = bytes4(keccak256("getStewards()"));
    bytes4 private constant SEL_IS_INVESTOR_WL = bytes4(keccak256("isInvestorWhitelisted(address)"));
    bytes4 private constant SEL_IS_PROPOSER_WL = bytes4(keccak256("isProposerWhitelisted(address)"));

    // Proposal Facet Selectors
    bytes4 private constant SEL_SUBMIT_PROPOSAL = bytes4(keccak256("submitProposal(uint8)"));
    bytes4 private constant SEL_SPONSOR_PROPOSAL = bytes4(keccak256("sponsorProposal(bytes32)"));
    bytes4 private constant SEL_CANCEL_PROPOSAL = bytes4(keccak256("cancelProposal(bytes32)"));
    bytes4 private constant SEL_EXECUTE_PROPOSAL = bytes4(keccak256("executeProposal(bytes32)"));
    bytes4 private constant SEL_GET_PROPOSAL = bytes4(keccak256("getProposal(bytes32)"));
    bytes4 private constant SEL_GET_PROPOSAL_COUNT = bytes4(keccak256("getProposalCount()"));
    bytes4 private constant SEL_GET_ALL_PROPOSAL_IDS = bytes4(keccak256("getAllProposalIds()"));
    bytes4 private constant SEL_IS_PROPOSAL_ACTIVE = bytes4(keccak256("isProposalActive(bytes32)"));

    // Governance Facet Selectors
    bytes4 private constant SEL_SUBMIT_VOTE = bytes4(keccak256("submitVote(bytes32,uint8)"));
    bytes4 private constant SEL_PROCESS_VOTE_RESULT = bytes4(keccak256("processVotingResult(bytes32)"));
    bytes4 private constant SEL_HAS_VOTED = bytes4(keccak256("hasVoted(bytes32,address)"));
    bytes4 private constant SEL_GET_VOTE = bytes4(keccak256("getVote(bytes32,address)"));
    bytes4 private constant SEL_GET_VOTING_RESULT = bytes4(keccak256("getVotingResult(bytes32)"));
    bytes4 private constant SEL_GET_TOTAL_VOTING_POWER = bytes4(keccak256("getTotalVotingPower()"));
    bytes4 private constant SEL_GET_VOTING_CONFIG = bytes4(keccak256("getVotingConfig()"));

    // Funding Facet Selectors
    bytes4 private constant SEL_DEPOSIT = bytes4(keccak256("deposit(bytes32)"));
    bytes4 private constant SEL_WITHDRAW = bytes4(keccak256("withdraw(bytes32)"));
    bytes4 private constant SEL_DISTRIBUTE_FUNDS = bytes4(keccak256("distributeFunds(bytes32)"));
    bytes4 private constant SEL_GET_FUNDING_INFO = bytes4(keccak256("getFundingInfo(bytes32)"));
    bytes4 private constant SEL_GET_CONTRIBUTION = bytes4(keccak256("getContribution(bytes32,address)"));
    bytes4 private constant SEL_GET_CONTRIBUTORS = bytes4(keccak256("getContributors(bytes32)"));
    bytes4 private constant SEL_GET_BALANCE = bytes4(keccak256("getBalance()"));
    bytes4 private constant SEL_EMERGENCY_WITHDRAW = bytes4(keccak256("emergencyWithdraw()"));
    // ========== End of Cached Selectors ==========


    constructor() {
        // Deploy core facets once
        diamondCutFacet = address(new DiamondCutFacet());
        diamondLoupeFacet = address(new DiamondLoupeFacet());
        ownershipFacet = address(new OwnershipFacet());
        diamondInit = address(new DiamondInit());
        daoInit = address(new DAOInit());
    }

    /**
     * @notice Create a new DAO with Diamond pattern
     * @param config DAO configuration
     * @return diamond Address of the newly created diamond
     */
    function createDAO(
        DAOConfig calldata config
    ) external returns (address diamond) {
        require(bytes(config.name).length > 0, "DAOFactory: Name required");
        require(config.founders.length > 0, "DAOFactory: Founders required");
        require(
            config.founders.length == config.allocations.length,
            "DAOFactory: Founders/allocations mismatch"
        );

        // 1. Deploy Diamond proxy with factory as temporary owner
        // This allows factory to install facets
        diamond = _deployDiamond(address(this));

        // 2. Install core facets (factory is owner, so this works)
        _installCoreFacets(diamond);

        // 3. Install business facets
        _installBusinessFacets(diamond);

        // 4. Initialize DiamondInit (add ERC165 support)
        _initializeDiamond(diamond);

        // 5. Initialize DAO data
        _initializeDAOData(diamond, config);

        // 6. Transfer ownership to the actual creator
        _transferOwnership(diamond, msg.sender);

        emit DAOCreated(diamond, msg.sender, config.daoType, config.name);
        return diamond;
    }

    /**
     * @notice Deploy Diamond proxy
     */
    function _deployDiamond(address owner) internal returns (address) {
        Diamond diamond = new Diamond(owner, diamondCutFacet);
        return address(diamond);
    }

    /**
     * @notice Transfer Diamond ownership
     */
    function _transferOwnership(address diamond, address newOwner) internal {
        // Get OwnershipFacet interface
        bytes4 selector = bytes4(keccak256("transferOwnership(address)"));
        (bool success, ) = diamond.call(abi.encodeWithSelector(selector, newOwner));
        require(success, "DAOFactory: Ownership transfer failed");
    }

    /**
     * @notice Install core facets to Diamond
     */
    function _installCoreFacets(address diamond) internal {
        // Prepare facet cuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);

        // DiamondLoupeFacet
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;
        loupeSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: diamondLoupeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // OwnershipFacet
        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = OwnershipFacet.transferOwnership.selector;
        ownershipSelectors[1] = OwnershipFacet.owner.selector;

        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: ownershipFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        // Execute diamond cut
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    /**
     * @notice Install business facets
     */
    function _installBusinessFacets(address diamond) internal {
        require(configurationFacet != address(0), "DAOFactory: ConfigurationFacet not set");
        require(membershipFacet != address(0), "DAOFactory: MembershipFacet not set");
        require(proposalFacet != address(0), "DAOFactory: ProposalFacet not set");
        require(governanceFacet != address(0), "DAOFactory: GovernanceFacet not set");
        require(fundingFacet != address(0), "DAOFactory: FundingFacet not set");

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](5);

        // ConfigurationFacet - use cached selectors
        bytes4[] memory configSelectors = new bytes4[](11);
        configSelectors[0] = SEL_SET_CONFIG;
        configSelectors[1] = SEL_GET_CONFIG;
        configSelectors[2] = SEL_SET_ADDR_CONFIG;
        configSelectors[3] = SEL_GET_ADDR_CONFIG;
        configSelectors[4] = SEL_SET_STR_CONFIG;
        configSelectors[5] = SEL_GET_STR_CONFIG;
        configSelectors[6] = SEL_BATCH_SET_CONFIG;
        configSelectors[7] = SEL_DAO_NAME;
        configSelectors[8] = SEL_DAO_TYPE;
        configSelectors[9] = SEL_DAO_CREATOR;
        configSelectors[10] = SEL_CREATED_AT;

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: configurationFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: configSelectors
        });

        // MembershipFacet - use cached selectors
        bytes4[] memory memberSelectors = new bytes4[](16);
        memberSelectors[0] = SEL_REGISTER_MEMBER;
        memberSelectors[1] = SEL_REMOVE_MEMBER;
        memberSelectors[2] = SEL_ADD_STEWARD;
        memberSelectors[3] = SEL_REMOVE_STEWARD;
        memberSelectors[4] = SEL_UPDATE_SHARES;
        memberSelectors[5] = SEL_WHITELIST_INVESTOR;
        memberSelectors[6] = SEL_WHITELIST_PROPOSER;
        memberSelectors[7] = SEL_BATCH_REGISTER;
        memberSelectors[8] = SEL_IS_MEMBER;
        memberSelectors[9] = SEL_IS_STEWARD;
        memberSelectors[10] = SEL_GET_SHARES;
        memberSelectors[11] = SEL_GET_MEMBER_INFO;
        memberSelectors[12] = SEL_GET_MEMBER_COUNT;
        memberSelectors[13] = SEL_GET_STEWARDS;
        memberSelectors[14] = SEL_IS_INVESTOR_WL;
        memberSelectors[15] = SEL_IS_PROPOSER_WL;

        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: membershipFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: memberSelectors
        });

        // ProposalFacet - use cached selectors
        bytes4[] memory proposalSelectors = new bytes4[](8);
        proposalSelectors[0] = SEL_SUBMIT_PROPOSAL;
        proposalSelectors[1] = SEL_SPONSOR_PROPOSAL;
        proposalSelectors[2] = SEL_CANCEL_PROPOSAL;
        proposalSelectors[3] = SEL_EXECUTE_PROPOSAL;
        proposalSelectors[4] = SEL_GET_PROPOSAL;
        proposalSelectors[5] = SEL_GET_PROPOSAL_COUNT;
        proposalSelectors[6] = SEL_GET_ALL_PROPOSAL_IDS;
        proposalSelectors[7] = SEL_IS_PROPOSAL_ACTIVE;

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: proposalFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: proposalSelectors
        });

        // GovernanceFacet - use cached selectors
        bytes4[] memory govSelectors = new bytes4[](7);
        govSelectors[0] = SEL_SUBMIT_VOTE;
        govSelectors[1] = SEL_PROCESS_VOTE_RESULT;
        govSelectors[2] = SEL_HAS_VOTED;
        govSelectors[3] = SEL_GET_VOTE;
        govSelectors[4] = SEL_GET_VOTING_RESULT;
        govSelectors[5] = SEL_GET_TOTAL_VOTING_POWER;
        govSelectors[6] = SEL_GET_VOTING_CONFIG;

        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: governanceFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: govSelectors
        });

        // FundingFacet - use cached selectors
        bytes4[] memory fundingSelectors = new bytes4[](8);
        fundingSelectors[0] = SEL_DEPOSIT;
        fundingSelectors[1] = SEL_WITHDRAW;
        fundingSelectors[2] = SEL_DISTRIBUTE_FUNDS;
        fundingSelectors[3] = SEL_GET_FUNDING_INFO;
        fundingSelectors[4] = SEL_GET_CONTRIBUTION;
        fundingSelectors[5] = SEL_GET_CONTRIBUTORS;
        fundingSelectors[6] = SEL_GET_BALANCE;
        fundingSelectors[7] = SEL_EMERGENCY_WITHDRAW;

        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: fundingFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: fundingSelectors
        });

        // Execute diamond cut
        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
    }

    /**
     * @notice Initialize DiamondInit to add ERC165 support
     */
    function _initializeDiamond(address diamond) internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);
        
        // Prepare init call
        bytes memory initCalldata = abi.encodeWithSelector(
            DiamondInit.init.selector
        );

        // Execute with init
        IDiamondCut(diamond).diamondCut(cuts, diamondInit, initCalldata);
    }

    /**
     * @notice Initialize DAO-specific data
     * @dev Uses delegatecall to DAOInit to set DAO metadata and register founders
     */
    function _initializeDAOData(
        address diamond,
        DAOConfig calldata config
    ) internal {
        // Prepare init call to DAOInit
        bytes memory initCalldata = abi.encodeWithSignature(
            "initDAO(string,string,address,address[],uint256[],uint256,uint256,uint256)",
            config.name,
            config.daoType,
            msg.sender, // creator
            config.founders,
            config.allocations,
            config.votingPeriod,
            config.quorum,
            config.majority
        );

        // Execute via diamondCut with empty cuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);
        IDiamondCut(diamond).diamondCut(cuts, daoInit, initCalldata);
    }

    /**
     * @notice Set business facet addresses
     * @dev Called after deploying business facets
     * @dev In production, should be restricted to owner or made immutable
     */
    function setBusinessFacets(
        address _governanceFacet,
        address _fundingFacet,
        address _membershipFacet,
        address _proposalFacet,
        address _configurationFacet
    ) external {
        // No access control for flexibility in testing and initial setup
        // In production, consider adding access control or setting in constructor
        governanceFacet = _governanceFacet;
        fundingFacet = _fundingFacet;
        membershipFacet = _membershipFacet;
        proposalFacet = _proposalFacet;
        configurationFacet = _configurationFacet;
    }

    /**
     * @notice Get factory version
     */
    function version() external pure returns (string memory) {
        return "1.0.0-alpha";
    }
}
