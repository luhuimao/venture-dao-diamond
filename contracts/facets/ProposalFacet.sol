// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ProposalFacet
 * @notice Manages proposal lifecycle (create, sponsor, cancel, execute)
 * @dev Migrated from FlexFunding and ProposalAdapter
 */

import {LibDAOStorage} from "../libraries/LibDAOStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract ProposalFacet {
    event ProposalCreated(
        bytes32 indexed proposalId,
        address indexed proposer,
        LibDAOStorage.ProposalType proposalType
    );
    event ProposalSponsored(bytes32 indexed proposalId, address indexed sponsor);
    event ProposalCancelled(bytes32 indexed proposalId);
    event ProposalExecuted(bytes32 indexed proposalId);

    /**
     * @notice Submit a new proposal
     * @param proposalType Type of proposal
     * @return proposalId Generated proposal ID
     */
    function submitProposal(
        LibDAOStorage.ProposalType proposalType
    ) external returns (bytes32 proposalId) {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        
        // Check proposer authorization
        require(
            ds.proposerWhitelist[msg.sender] || 
            ds.members[msg.sender].isSteward,
            "ProposalFacet: Not authorized"
        );
        
        // Generate proposal ID
        ds.proposalCount++;
        proposalId = keccak256(
            abi.encodePacked(
                block.timestamp,
                msg.sender,
                ds.proposalCount
            )
        );
        
        // Create proposal
        ds.proposals[proposalId] = LibDAOStorage.Proposal({
            id: proposalId,
            proposer: msg.sender,
            createdAt: block.timestamp,
            votingEndTime: 0, // Set when sponsored
            yesVotes: 0,
            noVotes: 0,
            status: LibDAOStorage.ProposalStatus.Pending,
            proposalType: proposalType
        });
        
        ds.proposalIds.push(proposalId);
        
        emit ProposalCreated(proposalId, msg.sender, proposalType);
        return proposalId;
    }

    /**
     * @notice Sponsor a proposal to start voting
     * @param proposalId Proposal ID
     */
    function sponsorProposal(bytes32 proposalId) external {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        LibDAOStorage.Proposal storage proposal = ds.proposals[proposalId];
        
        require(proposal.id != bytes32(0), "ProposalFacet: Proposal not found");
        require(
            proposal.status == LibDAOStorage.ProposalStatus.Pending,
            "ProposalFacet: Invalid status"
        );
        require(
            ds.members[msg.sender].isSteward,
            "ProposalFacet: Only stewards can sponsor"
        );
        
        // Get voting period from configuration
        uint256 votingPeriod = ds.configuration[keccak256("VOTING_PERIOD")];
        if (votingPeriod == 0) votingPeriod = 7 days; // Default
        
        proposal.status = LibDAOStorage.ProposalStatus.Active;
        proposal.votingEndTime = block.timestamp + votingPeriod;
        
        emit ProposalSponsored(proposalId, msg.sender);
    }

    /**
     * @notice Cancel a proposal (only proposer or owner)
     * @param proposalId Proposal ID
     */
    function cancelProposal(bytes32 proposalId) external {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        LibDAOStorage.Proposal storage proposal = ds.proposals[proposalId];
        
        require(proposal.id != bytes32(0), "ProposalFacet: Proposal not found");
        require(
            msg.sender == proposal.proposer || 
            msg.sender == LibDiamond.contractOwner(),
            "ProposalFacet: Not authorized"
        );
        require(
            proposal.status == LibDAOStorage.ProposalStatus.Pending ||
            proposal.status == LibDAOStorage.ProposalStatus.Active,
            "ProposalFacet: Cannot cancel"
        );
        
        proposal.status = LibDAOStorage.ProposalStatus.Cancelled;
        
        emit ProposalCancelled(proposalId);
    }

    /**
     * @notice Mark proposal as executed
     * @param proposalId Proposal ID
     */
    function executeProposal(bytes32 proposalId) external {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        LibDAOStorage.Proposal storage proposal = ds.proposals[proposalId];
        
        require(proposal.id != bytes32(0), "ProposalFacet: Proposal not found");
        require(
            proposal.status == LibDAOStorage.ProposalStatus.Passed,
            "ProposalFacet: Not passed"
        );
        require(
            ds.members[msg.sender].isSteward,
            "ProposalFacet: Only stewards can execute"
        );
        
        proposal.status = LibDAOStorage.ProposalStatus.Executed;
        
        emit ProposalExecuted(proposalId);
    }

    // View functions
    function getProposal(bytes32 proposalId) external view returns (
        bytes32 id,
        address proposer,
        uint256 createdAt,
        uint256 votingEndTime,
        uint256 yesVotes,
        uint256 noVotes,
        LibDAOStorage.ProposalStatus status,
        LibDAOStorage.ProposalType proposalType
    ) {
        LibDAOStorage.Proposal storage proposal = LibDAOStorage.daoStorage().proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.createdAt,
            proposal.votingEndTime,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.status,
            proposal.proposalType
        );
    }

    function getProposalCount() external view returns (uint256) {
        return LibDAOStorage.daoStorage().proposalCount;
    }

    function getAllProposalIds() external view returns (bytes32[] memory) {
        return LibDAOStorage.daoStorage().proposalIds;
    }

    function isProposalActive(bytes32 proposalId) external view returns (bool) {
        LibDAOStorage.Proposal storage proposal = LibDAOStorage.daoStorage().proposals[proposalId];
        return proposal.status == LibDAOStorage.ProposalStatus.Active &&
               block.timestamp <= proposal.votingEndTime;
    }
}
