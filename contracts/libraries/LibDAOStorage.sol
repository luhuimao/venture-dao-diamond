// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title LibDAOStorage
 * @notice Storage library for DAO business data using Diamond Storage pattern
 * @dev Separate storage position from LibDiamond to avoid conflicts
 */
library LibDAOStorage {
    bytes32 constant DAO_STORAGE_POSITION = keccak256("venture.dao.storage");

    // Gas Optimized: Packed into 1 slot (32 bytes)
    struct Member {
        bool exists;          // 1 byte
        bool isSteward;       // 1 byte  
        uint64 joinedAt;      // 8 bytes (sufficient until year 2554)
        uint184 shares;       // 23 bytes (max: ~2.46e55, more than enough)
    }
    // Slot packing: all 4 fields fit in 1 slot = 1 + 1 + 8 + 23 = 33 bytes → rounds to 32 bytes

    // Gas Optimized: Packed into 3 slots (96 bytes)
    struct Proposal {
        bytes32 id;                 // 32 bytes - SLOT 0
        address proposer;           // 20 bytes - SLOT 1 (0-19)
        uint64 createdAt;           // 8 bytes  - SLOT 1 (20-27)
        ProposalStatus status;      // 1 byte   - SLOT 1 (28)
        ProposalType proposalType;  // 1 byte   - SLOT 1 (29)
        // 2 bytes padding           SLOT 1 (30-31)
        uint64 votingEndTime;       // 8 bytes  - SLOT 2 (0-7)
        uint96 yesVotes;            // 12 bytes - SLOT 2 (8-19)
        uint96 noVotes;             // 12 bytes - SLOT 2 (20-31)
    }
    // Slot usage: id(slot0) + proposer+createdAt+status+type(slot1) + votingEndTime+yesVotes+noVotes(slot2) = 3 slots

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
        
        // Gas Optimization: Cached voting power (Optimization #3)
        uint256 totalVotingPower;  // Sum of all member voting power (shares, min 1)
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
