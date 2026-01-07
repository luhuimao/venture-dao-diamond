// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Diamond} from "./Diamond.sol";
import {DiamondCutFacet} from "./facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "./facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "./facets/OwnershipFacet.sol";
import {DiamondInit} from "./upgradeInitializers/DiamondInit.sol";
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
    }

    // Facet addresses (deployed once, reused for all DAOs)
    address public immutable diamondCutFacet;
    address public immutable diamondLoupeFacet;
    address public immutable ownershipFacet;
    address public immutable diamondInit;

    // Future business facets (to be added in Phase 2)
    address public governanceFacet;
    address public fundingFacet;
    address public membershipFacet;
    address public proposalFacet;
    address public configurationFacet;

    constructor() {
        // Deploy core facets once
        diamondCutFacet = address(new DiamondCutFacet());
        diamondLoupeFacet = address(new DiamondLoupeFacet());
        ownershipFacet = address(new OwnershipFacet());
        diamondInit = address(new DiamondInit());
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

        // 1. Deploy Diamond proxy
        diamond = _deployDiamond(msg.sender);

        // 2. Install core facets
        _installCoreFacets(diamond);

        // 3. Install business facets
        _installBusinessFacets(diamond);

        // 4. Initialize DiamondInit (add ERC165 support)
        _initializeDiamond(diamond);

        // 5. Initialize DAO data
        _initializeDAOData(diamond, config);

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

        // ConfigurationFacet - basic selectors
        bytes4[] memory configSelectors = new bytes4[](10);
        configSelectors[0] = bytes4(keccak256("setConfiguration(bytes32,uint256)"));
        configSelectors[1] = bytes4(keccak256("getConfiguration(bytes32)"));
        configSelectors[2] = bytes4(keccak256("setAddressConfiguration(bytes32,address)"));
        configSelectors[3] = bytes4(keccak256("getAddressConfiguration(bytes32)"));
        configSelectors[4] = bytes4(keccak256("setStringConfiguration(bytes32,string)"));
        configSelectors[5] = bytes4(keccak256("getStringConfiguration(bytes32)"));
        configSelectors[6] = bytes4(keccak256("batchSetConfiguration(bytes32[],uint256[])"));
        configSelectors[7] = bytes4(keccak256("daoName()"));
        configSelectors[8] = bytes4(keccak256("daoType()"));
        configSelectors[9] = bytes4(keccak256("daoCreator()"));

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: configurationFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: configSelectors
        });

        // MembershipFacet - basic selectors
        bytes4[] memory memberSelectors = new bytes4[](12);
        memberSelectors[0] = bytes4(keccak256("registerMember(address,uint256)"));
        memberSelectors[1] = bytes4(keccak256("removeMember(address)"));
        memberSelectors[2] = bytes4(keccak256("addSteward(address)"));
        memberSelectors[3] = bytes4(keccak256("removeSteward(address)"));
        memberSelectors[4] = bytes4(keccak256("isMember(address)"));
        memberSelectors[5] = bytes4(keccak256("isSteward(address)"));
        memberSelectors[6] = bytes4(keccak256("getMemberShares(address)"));
        memberSelectors[7] = bytes4(keccak256("getMemberCount()"));
        memberSelectors[8] = bytes4(keccak256("getStewards()"));
        memberSelectors[9] = bytes4(keccak256("whitelistInvestor(address)"));
        memberSelectors[10] = bytes4(keccak256("whitelistProposer(address)"));
        memberSelectors[11] = bytes4(keccak256("batchRegisterMembers(address[],uint256[])"));

        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: membershipFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: memberSelectors
        });

        // ProposalFacet - basic selectors
        bytes4[] memory proposalSelectors = new bytes4[](7);
        proposalSelectors[0] = bytes4(keccak256("submitProposal(uint8)"));
        proposalSelectors[1] = bytes4(keccak256("sponsorProposal(bytes32)"));
        proposalSelectors[2] = bytes4(keccak256("cancelProposal(bytes32)"));
        proposalSelectors[3] = bytes4(keccak256("executeProposal(bytes32)"));
        proposalSelectors[4] = bytes4(keccak256("getProposal(bytes32)"));
        proposalSelectors[5] = bytes4(keccak256("getProposalCount()"));
        proposalSelectors[6] = bytes4(keccak256("getAllProposalIds()"));

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: proposalFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: proposalSelectors
        });

        // GovernanceFacet - basic selectors
        bytes4[] memory govSelectors = new bytes4[](6);
        govSelectors[0] = bytes4(keccak256("submitVote(bytes32,uint8)"));
        govSelectors[1] = bytes4(keccak256("processVotingResult(bytes32)"));
        govSelectors[2] = bytes4(keccak256("hasVoted(bytes32,address)"));
        govSelectors[3] = bytes4(keccak256("getVote(bytes32,address)"));
        govSelectors[4] = bytes4(keccak256("getVotingResult(bytes32)"));
        govSelectors[5] = bytes4(keccak256("getTotalVotingPower()"));

        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: governanceFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: govSelectors
        });

        // FundingFacet - basic selectors
        bytes4[] memory fundingSelectors = new bytes4[](6);
        fundingSelectors[0] = bytes4(keccak256("deposit(bytes32)"));
        fundingSelectors[1] = bytes4(keccak256("withdraw(bytes32)"));
        fundingSelectors[2] = bytes4(keccak256("distributeFunds(bytes32)"));
        fundingSelectors[3] = bytes4(keccak256("getFundingInfo(bytes32)"));
        fundingSelectors[4] = bytes4(keccak256("getContribution(bytes32,address)"));
        fundingSelectors[5] = bytes4(keccak256("getBalance()"));

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
     * @dev Uses delegatecall context, so storage is in Diamond
     */
    function _initializeDAOData(
        address diamond,
        DAOConfig calldata config
    ) internal {
        // Access DAO storage through library
        // Note: This won't work directly in factory, needs to be done via init contract
        // For now, this is a placeholder showing the pattern
        
        // In Phase 2, we'll create a DAOInit contract that:
        // 1. Sets DAO name, type, creator
        // 2. Registers founders as members
        // 3. Allocates initial shares
        // 4. Sets default configurations
    }

    /**
     * @notice Set business facet addresses (admin only)
     * @dev Called after deploying business facets
     */
    function setBusinessFacets(
        address _governanceFacet,
        address _fundingFacet,
        address _membershipFacet,
        address _proposalFacet,
        address _configurationFacet
    ) external {
        // In production, add onlyOwner modifier
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
