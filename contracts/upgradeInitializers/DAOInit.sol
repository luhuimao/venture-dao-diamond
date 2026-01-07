// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDAOStorage} from "../libraries/LibDAOStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

/**
 * @title DAOInit
 * @notice Initializer for DAO-specific data
 * @dev Called during DAO creation to set up initial state
 */
contract DAOInit {
    /**
     * @notice Initialize DAO with metadata and founders
     * @param name DAO name
     * @param daoType DAO type (flex/vintage/collective)
     * @param creator DAO creator address
     * @param founders Array of founder addresses
     * @param allocations Array of founder share allocations
     */
    function initDAO(
        string calldata name,
        string calldata daoType,
        address creator,
        address[] calldata founders,
        uint256[] calldata allocations,
        uint256 votingPeriod,
        uint256 quorum,
        uint256 majority
    ) external {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        
        // Set DAO metadata
        ds.name = name;
        ds.daoType = daoType;
        ds.creator = creator;
        ds.createdAt = block.timestamp;
        
        // Register founders as members
        for (uint256 i = 0; i < founders.length; i++) {
            address founder = founders[i];
            uint256 shares = allocations[i];
            
            require(!ds.members[founder].exists, "DAOInit: Founder already exists");
            
            ds.members[founder] = LibDAOStorage.Member({
                exists: true,
                isSteward: false,
                shares: shares,
                joinedAt: block.timestamp
            });
            
            ds.memberList.push(founder);
            ds.memberCount++;
        }
        
        // Set configurations
        ds.configuration[keccak256("VOTING_PERIOD")] = votingPeriod;
        ds.configuration[keccak256("QUORUM")] = quorum;
        ds.configuration[keccak256("MAJORITY")] = majority;
    }
}
