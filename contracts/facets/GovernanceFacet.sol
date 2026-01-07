// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title GovernanceFacet
 * @notice Manages voting mechanics and proposal voting
 * @dev Migrated from FlexVoting and FlexPollingVoting
 */

import {LibDAOStorage} from "../libraries/LibDAOStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract GovernanceFacet {
    event VoteSubmitted(
        bytes32 indexed proposalId,
        address indexed voter,
        uint8 voteValue,
        uint256 weight
    );
    event VotingConcluded(
        bytes32 indexed proposalId,
        bool passed,
        uint256 yesVotes,
        uint256 noVotes
    );

    /**
     * @notice Submit a vote on a proposal
     * @param proposalId Proposal ID
     * @param voteValue 0=No, 1=Yes
     */
    function submitVote(bytes32 proposalId, uint8 voteValue) external {
        require(voteValue <= 1, "GovernanceFacet: Invalid vote value");
        
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        LibDAOStorage.Proposal storage proposal = ds.proposals[proposalId];
        LibDAOStorage.VotingData storage votingData = ds.votingRecords[proposalId];
        
        require(proposal.id != bytes32(0), "GovernanceFacet: Proposal not found");
        require(
            proposal.status == LibDAOStorage.ProposalStatus.Active,
            "GovernanceFacet: Not active"
        );
        require(
            block.timestamp <= proposal.votingEndTime,
            "GovernanceFacet: Voting ended"
        );
        require(
            ds.members[msg.sender].exists,
            "GovernanceFacet: Not a member"
        );
        require(
            !votingData.hasVoted[msg.sender],
            "GovernanceFacet: Already voted"
        );
        
        // Get voting weight (shares)
        uint256 weight = ds.members[msg.sender].shares;
        if (weight == 0) weight = 1; // Minimum 1 vote per member
        
        // Record vote
        votingData.hasVoted[msg.sender] = true;
        votingData.voteValue[msg.sender] = voteValue;
        votingData.totalVoters++;
        
        // Update vote counts
        if (voteValue == 1) {
            proposal.yesVotes += weight;
        } else {
            proposal.noVotes += weight;
        }
        
        emit VoteSubmitted(proposalId, msg.sender, voteValue, weight);
    }

    /**
     * @notice Process voting result after voting period ends
     * @param proposalId Proposal ID
     */
    function processVotingResult(bytes32 proposalId) external {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        LibDAOStorage.Proposal storage proposal = ds.proposals[proposalId];
        
        require(proposal.id != bytes32(0), "GovernanceFacet: Proposal not found");
        require(
            proposal.status == LibDAOStorage.ProposalStatus.Active,
            "GovernanceFacet: Not active"
        );
        require(
            block.timestamp > proposal.votingEndTime,
            "GovernanceFacet: Voting not ended"
        );
        
        // Get quorum and majority requirements
        uint256 quorum = ds.configuration[keccak256("QUORUM")];  
        uint256 majority = ds.configuration[keccak256("MAJORITY")];
        
        if (quorum == 0) quorum = 20; // 20% default
        if (majority == 0) majority = 50; // 50% default
        
        // Calculate total voting power
        uint256 totalVotes = proposal.yesVotes + proposal.noVotes;
        uint256 totalPower = _getTotalVotingPower();
        
        // Check quorum
        bool quorumReached = (totalVotes * 100) >= (totalPower * quorum);
        
        // Check majority
        bool majorityReached = proposal.yesVotes > proposal.noVotes &&
                              (proposal.yesVotes * 100) >= (totalVotes * majority);
        
        // Determine result
        bool passed = quorumReached && majorityReached;
        
        proposal.status = passed ? 
            LibDAOStorage.ProposalStatus.Passed : 
            LibDAOStorage.ProposalStatus.Failed;
        
        emit VotingConcluded(proposalId, passed, proposal.yesVotes, proposal.noVotes);
    }

    /**
     * @notice Calculate total voting power (sum of all member shares)
     */
    function _getTotalVotingPower() internal view returns (uint256 total) {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        address[] memory members = ds.memberList;
        
        uint256 length = members.length;
        for (uint256 i = 0; i < length;) {
            uint256 shares = ds.members[members[i]].shares;
            total += (shares == 0 ? 1 : shares); // Minimum 1 vote
            unchecked { ++i; }
        }
    }

    // View functions
    function hasVoted(bytes32 proposalId, address voter) external view returns (bool) {
        return LibDAOStorage.daoStorage().votingRecords[proposalId].hasVoted[voter];
    }

    function getVote(bytes32 proposalId, address voter) external view returns (uint8) {
        require(
            LibDAOStorage.daoStorage().votingRecords[proposalId].hasVoted[voter],
            "GovernanceFacet: No vote"
        );
        return LibDAOStorage.daoStorage().votingRecords[proposalId].voteValue[voter];
    }

    function getVotingResult(bytes32 proposalId) external view returns (
        uint256 yesVotes,
        uint256 noVotes,
        uint256 totalVoters
    ) {
        LibDAOStorage.Proposal storage proposal = LibDAOStorage.daoStorage().proposals[proposalId];
        LibDAOStorage.VotingData storage votingData = LibDAOStorage.daoStorage().votingRecords[proposalId];
        
        return (proposal.yesVotes, proposal.noVotes, votingData.totalVoters);
    }

    function getTotalVotingPower() external view returns (uint256) {
        return _getTotalVotingPower();
    }

    function getVotingConfig() external view returns (uint256 quorum, uint256 majority) {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        quorum = ds.configuration[keccak256("QUORUM")];
        majority = ds.configuration[keccak256("MAJORITY")];
        
        if (quorum == 0) quorum = 20;
        if (majority == 0) majority = 50;
        
        return (quorum, majority);
    }
}
