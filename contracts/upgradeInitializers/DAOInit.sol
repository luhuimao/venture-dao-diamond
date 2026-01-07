// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDAOStorage} from "../libraries/LibDAOStorage.sol";

/**
 * @title DAOInit
 * @notice Initialization contract for DAO-specific data
 * @dev Extended to support UnifiedDAOConfig with full parameter compatibility
 */
contract DAOInit {
    // ========== Gas Optimization: Hash Constants ==========
    bytes32 private constant FLEX_HASH = keccak256("flex");
    bytes32 private constant VINTAGE_HASH = keccak256("vintage");
    bytes32 private constant COLLECTIVE_HASH = keccak256("collective");
    bytes32 private constant GOVERNOR_HASH = keccak256("GOVERNOR");
    bytes32 private constant PROPOSER_HASH = keccak256("PROPOSER");
    bytes32 private constant INVESTOR_HASH = keccak256("INVESTOR");
    
    /**
     * @notice Initialize DAO storage with basic configuration (Legacy - Simple)
     */
    function init(
        string memory daoName,
        string memory daoType,
        address creator,
        address[] memory founders,
        uint256[] memory allocations
    ) external {
        _initBase(daoName, daoType, creator, founders, allocations);
        
        // Set default configurations
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        ds.configuration[keccak256("VOTING_PERIOD")] = 7 days;
        ds.configuration[keccak256("QUORUM")] = 20;
        ds.configuration[keccak256("SUPER_MAJORITY")] = 60;
    }
    
    /**
     * @notice Initialize DAO with voting config (Legacy - for DAOFactory compatibility)
     */
    function initDAO(
        string memory daoName,
        string memory daoType,
        address creator,
        address[] memory founders,
        uint256[] memory allocations,
        uint256 votingPeriod,
        uint256 quorum,
        uint256 majority
    ) external {
        _initBase(daoName, daoType, creator, founders, allocations);
        
        // Set provided voting configuration
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        ds.configuration[keccak256("VOTING_PERIOD")] = votingPeriod;
        ds.configuration[keccak256("QUORUM")] = quorum;
        ds.configuration[keccak256("SUPER_MAJORITY")] = majority;
    }
    
    /**
     * @notice Internal function to initialize base DAO data
     */
    function _initBase(
        string memory daoName,
        string memory daoType,
        address creator,
        address[] memory founders,
        uint256[] memory allocations
    ) internal {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        
        // Set DAO metadata
        ds.name = daoName;
        ds.daoType = daoType;
        ds.creator = creator;
        ds.createdAt = block.timestamp;
        
        // Register genesis members (optimized loop)
        uint256 foundersLength = founders.length;
        for (uint256 i; i < foundersLength;) {
            address founder = founders[i];
            uint256 shares = allocations[i];
            
            require(!ds.members[founder].exists, "DAOInit: Founder already exists");
            
            ds.members[founder] = LibDAOStorage.Member({
                exists: true,
                isSteward: false,
                joinedAt: uint64(block.timestamp),
                shares: uint184(shares)
            });
            
            ds.memberList.push(founder);
            ds.memberCount++;
            
            // Update cached voting power (Optimization #3)
            uint256 votingPower = (shares == 0 ? 1 : shares);
            ds.totalVotingPower += votingPower;
            
            unchecked { ++i; }
        }
    }
    
    /**
     * @notice Initialize DAO storage with unified configuration (Production)
     * @param config bytes-encoded UnifiedDAOConfig
     */
    function initUnified(bytes memory config) external {
        // Decode configuration data
        (
            string memory name,
            string memory daoType,
            address creator,
            address[] memory genesisMembers,
            uint256[] memory genesisAllocations,
            bytes memory votingConfigData,
            bytes memory governorConfigData,
            bytes memory feeConfigData,
            bytes memory advancedConfigData
        ) = abi.decode(
            config,
            (string, string, address, address[], uint256[], bytes, bytes, bytes, bytes)
        );
        
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        
        // Set DAO metadata
        ds.name = name;
        ds.daoType = daoType;
        ds.creator = creator;
        ds.createdAt = block.timestamp;
        
        // Register genesis members (optimized with unchecked loop + batch storage)
        uint256 membersLength = genesisMembers.length;
        uint256 totalPower;
        
        for (uint256 i; i < membersLength;) {
            address member = genesisMembers[i];
            uint256 shares = genesisAllocations[i];
            
            ds.members[member] = LibDAOStorage.Member({
                exists: true,
                isSteward: true,  // Genesis members are stewards
                joinedAt: uint64(block.timestamp),
                shares: uint184(shares)
            });
            
            ds.memberList.push(member);
            ds.stewards.push(member);
            
            uint256 votingPower = (shares == 0 ? 1 : shares);
            totalPower += votingPower;
            
            unchecked { ++i; }
        }
        
        // Batch storage writes (gas optimization)
        ds.memberCount = membersLength;
        ds.totalVotingPower = totalPower;
        
        // Decode and set voting configuration
        _setVotingConfig(votingConfigData);
        
        // Decode and set governor membership config
        if (governorConfigData.length > 0) {
            _setMembershipConfig(keccak256("GOVERNOR"), governorConfigData);
        }
        
        // Decode and set fee configuration
        if (feeConfigData.length > 0) {
            _setFeeConfig(daoType, feeConfigData);
        }
        
        // Decode and set advanced configuration
        if (advancedConfigData.length > 0) {
            _setAdvancedConfig(advancedConfigData);
        }
    }
    
    function _setVotingConfig(bytes memory data) internal {
        (
            uint256 votingPeriod,
            uint256 quorum,
            uint256 supportRequired,
            uint256 gracePeriod,
            uint256 executingPeriod
        ) = abi.decode(data, (uint256, uint256, uint256, uint256, uint256));
        
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        
        ds.configuration[keccak256("VOTING_PERIOD")] = votingPeriod;
        ds.configuration[keccak256("QUORUM")] = quorum;
        ds.configuration[keccak256("SUPER_MAJORITY")] = supportRequired;
        
        if (gracePeriod > 0) {
            ds.configuration[keccak256("GRACE_PERIOD")] = gracePeriod;
        }
        
        if (executingPeriod > 0) {
            ds.configuration[keccak256("EXECUTING_PERIOD")] = executingPeriod;
        }
    }
    
    function _setMembershipConfig(bytes32 configType, bytes memory data) internal {
        (
            bool enable,
            uint8 verifyType,
            address tokenAddress,
            uint256 tokenId,
            uint256 minAmount,
            address[] memory whitelist
        ) = abi.decode(data, (bool, uint8, address, uint256, uint256, address[]));
        
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        
        bytes32 enableKey = keccak256(abi.encodePacked(configType, "_ENABLE"));
        bytes32 typeKey = keccak256(abi.encodePacked(configType, "_VERIFY_TYPE"));
        bytes32 tokenKey = keccak256(abi.encodePacked(configType, "_TOKEN"));
        bytes32 tokenIdKey = keccak256(abi.encodePacked(configType, "_TOKEN_ID"));
        bytes32 minAmountKey = keccak256(abi.encodePacked(configType, "_MIN_AMOUNT"));
        
        ds.configuration[enableKey] = enable ? 1 : 0;
        ds.configuration[typeKey] = verifyType;
        ds.addressConfiguration[tokenKey] = tokenAddress;
        ds.configuration[tokenIdKey] = tokenId;
        ds.configuration[minAmountKey] = minAmount;
        
        // Store whitelist if provided (verifyType = 3) - optimized with constants
        if (verifyType == 3 && whitelist.length > 0) {
            uint256 wlLength = whitelist.length;
            
            if (configType == GOVERNOR_HASH) {
                for (uint256 i; i < wlLength;) {
                    ds.governorWhitelist[whitelist[i]] = true;
                    unchecked { ++i; }
                }
            } else if (configType == PROPOSER_HASH) {
                for (uint256 i; i < wlLength;) {
                    ds.proposerWhitelist[whitelist[i]] = true;
                    unchecked { ++i; }
                }
            } else if (configType == INVESTOR_HASH) {
                for (uint256 i; i < wlLength;) {
                    ds.investorWhitelist[whitelist[i]] = true;
                    unchecked { ++i; }
                }
            }
        }
    }
    
    function _setFeeConfig(string memory daoType, bytes memory data) internal {
        (
            uint256 managementFee,
            uint256 returnTokenManagementFee,
            uint256 redemptionFee,
            uint256 proposerRewardRatio,
            address fundRaisingToken
        ) = abi.decode(data, (uint256, uint256, uint256, uint256, address));
        
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        
        // Use precomputed hash constants (gas optimization)
        bytes32 daoTypeHash = keccak256(bytes(daoType));
        
        if (daoTypeHash == FLEX_HASH) {
            ds.configuration[keccak256("MANAGEMENT_FEE")] = managementFee;
            ds.configuration[keccak256("RETURN_TOKEN_MANAGEMENT_FEE")] = returnTokenManagementFee;
        } else if (daoTypeHash == COLLECTIVE_HASH) {
            ds.configuration[keccak256("REDEMPTION_FEE")] = redemptionFee;
            ds.configuration[keccak256("PROPOSER_REWARD_RATIO")] = proposerRewardRatio;
            ds.addressConfiguration[keccak256("FUND_RAISING_TOKEN")] = fundRaisingToken;
        }
        // Vintage uses managementFee
        if (daoTypeHash == VINTAGE_HASH) {
            ds.configuration[keccak256("MANAGEMENT_FEE")] = managementFee;
        }
    }
    
    /**
     * @notice Set advanced configuration options
     */
    function _setAdvancedConfig(bytes memory data) internal {
        (
            bool priorityDepositEnable,
            uint256 priorityPeriod,
            bool investorCapEnable,
            uint256 maxInvestors
        ) = abi.decode(data, (bool, uint256, bool, uint256));
        
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        
        // Priority deposit configuration
        if (priorityDepositEnable) {
            ds.configuration[keccak256("PRIORITY_DEPOSIT_ENABLE")] = 1;
            ds.configuration[keccak256("PRIORITY_PERIOD")] = priorityPeriod;
        }
        
        // Investor cap configuration
        if (investorCapEnable) {
            ds.configuration[keccak256("INVESTOR_CAP_ENABLE")] = 1;
            ds.configuration[keccak256("MAX_INVESTORS")] = maxInvestors;
        }
    }
}
