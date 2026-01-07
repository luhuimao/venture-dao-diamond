// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title LibDAOStorage
 * @notice Storage library for DAO business data using Diamond Storage pattern
 * @dev Separate storage position from LibDiamond to avoid conflicts
 */
library LibDAOStorage {
    bytes32 constant DAO_STORAGE_POSITION = keccak256("venture.dao.storage");

    struct Member {
        bool exists;
        bool isSteward;
        uint256 shares;
        uint256 joinedAt;
    }

    struct Proposal {
        bytes32 id;
        address proposer;
        uint256 createdAt;
        uint256 votingEndTime;
        uint256 yesVotes;
        uint256 noVotes;
        ProposalStatus status;
        ProposalType proposalType;
    }

    enum ProposalStatus {
        Pending,
        Active,
        Passed,
        Failed,
        Executed,
        Cancelled
    }

    enum ProposalType {
        Funding,
        Membership,
        Configuration,
        Governance
    }

    struct VotingData {
        mapping(address => bool) hasVoted;
        mapping(address => uint8) voteValue; // 0=no, 1=yes
        uint256 totalVoters;
    }

    struct FundingData {
        uint256 totalRaised;
        uint256 targetAmount;
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    struct DAOStorage {
        // DAO Metadata
        string name;
        string daoType; // "flex", "vintage", "collective"
        address creator;
        uint256 createdAt;
        
        // Members
        mapping(address => Member) members;
        address[] memberList;
        address[] stewards;
        
        // Proposals
        mapping(bytes32 => Proposal) proposals;
        bytes32[] proposalIds;
        mapping(bytes32 => VotingData) votingRecords;
        mapping(bytes32 => FundingData) fundingRecords;
        
        // Configuration
        mapping(bytes32 => uint256) configuration;
        mapping(bytes32 => address) addressConfiguration;
        mapping(bytes32 => string) stringConfiguration;
        
        // Whitelists
        mapping(address => bool) investorWhitelist;
        mapping(address => bool) proposerWhitelist;
        
        // Counters
        uint256 proposalCount;
        uint256 memberCount;
    }

    function daoStorage() internal pure returns (DAOStorage storage ds) {
        bytes32 position = DAO_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    // Helper functions
    function isMember(address account) internal view returns (bool) {
        return daoStorage().members[account].exists;
    }

    function isSteward(address account) internal view returns (bool) {
        return daoStorage().members[account].isSteward;
    }

    function getMemberShares(address account) internal view returns (uint256) {
        return daoStorage().members[account].shares;
    }
}
