// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MembershipFacet
 * @notice Manages DAO members, stewards, and whitelists
 * @dev Migrated from DaoRegistry and StewardManagement
 */

import {LibDAOStorage} from "../libraries/LibDAOStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract MembershipFacet {
    event MemberAdded(address indexed member, uint256 shares);
    event MemberRemoved(address indexed member);
    event StewardAdded(address indexed steward);
    event StewardRemoved(address indexed steward);
    event SharesUpdated(address indexed member, uint256 newShares);
    event InvestorWhitelisted(address indexed investor);
    event ProposerWhitelisted(address indexed proposer);

    /**
     * @notice Register a new member
     * @param member Member address
     * @param shares Initial shares
     */
    function registerMember(address member, uint256 shares) external {
        LibDiamond.enforceIsContractOwner();
        _registerMember(member, shares);
    }

    /**
     * @notice Internal function to register a member
     * @param member Member address
     * @param shares Initial shares
     */
    function _registerMember(address member, uint256 shares) internal {
        require(member != address(0), "MembershipFacet: Invalid address");
        
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        require(!ds.members[member].exists, "MembershipFacet: Member exists");
        
        ds.members[member] = LibDAOStorage.Member({
            exists: true,
            isSteward: false,
            shares: shares,
            joinedAt: block.timestamp
        });
        
        ds.memberList.push(member);
        ds.memberCount++;
        
        emit MemberAdded(member, shares);
    }

    /**
     * @notice Remove a member
     * @param member Member address
     */
    function removeMember(address member) external {
        LibDiamond.enforceIsContractOwner();
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        require(ds.members[member].exists, "MembershipFacet: Not a member");
        
        // Remove from stewards if applicable
        if (ds.members[member].isSteward) {
            _removeSteward(member);
        }
        
        delete ds.members[member];
        ds.memberCount--;
        
        emit MemberRemoved(member);
    }

    /**
     * @notice Add a steward
     * @param steward Steward address
     */
    function addSteward(address steward) external {
        LibDiamond.enforceIsContractOwner();
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        
        // Ensure member exists
        if (!ds.members[steward].exists) {
            _registerMember(steward, 0);
        }
        
        require(!ds.members[steward].isSteward, "MembershipFacet: Already steward");
        
        ds.members[steward].isSteward = true;
        ds.stewards.push(steward);
        
        emit StewardAdded(steward);
    }

    /**
     * @notice Remove a steward
     * @param steward Steward address  
     */
    function removeSteward(address steward) external {
        LibDiamond.enforceIsContractOwner();
        _removeSteward(steward);
    }

    function _removeSteward(address steward) internal {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        require(ds.members[steward].isSteward, "MembershipFacet: Not a steward");
        
        ds.members[steward].isSteward = false;
        
        // Remove from stewards array
        uint256 length = ds.stewards.length;
        for (uint256 i = 0; i < length;) {
            if (ds.stewards[i] == steward) {
                ds.stewards[i] = ds.stewards[length - 1];
                ds.stewards.pop();
                break;
            }
            unchecked { ++i; }
        }
        
        emit StewardRemoved(steward);
    }

    /**
     * @notice Update member shares
     * @param member Member address
     * @param newShares New share amount
     */
    function updateShares(address member, uint256 newShares) external {
        LibDiamond.enforceIsContractOwner();
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        require(ds.members[member].exists, "MembershipFacet: Not a member");
        
        ds.members[member].shares = newShares;
        emit SharesUpdated(member, newShares);
    }

    /**
     * @notice Add address to investor whitelist
     * @param investor Investor address
     */
    function whitelistInvestor(address investor) external {
        LibDiamond.enforceIsContractOwner();
        LibDAOStorage.daoStorage().investorWhitelist[investor] = true;
        emit InvestorWhitelisted(investor);
    }

    /**
     * @notice Add address to proposer whitelist
     * @param proposer Proposer address
     */
    function whitelistProposer(address proposer) external {
        LibDiamond.enforceIsContractOwner();
        LibDAOStorage.daoStorage().proposerWhitelist[proposer] = true;
        emit ProposerWhitelisted(proposer);
    }

    /**
     * @notice Batch register members
     * @param members Array of member addresses
     * @param shares Array of initial shares
     */
    function batchRegisterMembers(
        address[] calldata members,
        uint256[] calldata shares
    ) external {
        LibDiamond.enforceIsContractOwner();
        require(members.length == shares.length, "MembershipFacet: Length mismatch");
        
        uint256 length = members.length;
        for (uint256 i = 0; i < length;) {
            _registerMember(members[i], shares[i]);
            unchecked { ++i; }
        }
    }

    // View functions
    function isMember(address account) external view returns (bool) {
        return LibDAOStorage.isMember(account);
    }

    function isSteward(address account) external view returns (bool) {
        return LibDAOStorage.isSteward(account);
    }

    function getMemberShares(address account) external view returns (uint256) {
        return LibDAOStorage.getMemberShares(account);
    }

    function getMemberInfo(address account) external view returns (
        bool exists,
        bool isSteward_,
        uint256 shares,
        uint256 joinedAt
    ) {
        LibDAOStorage.Member storage member = LibDAOStorage.daoStorage().members[account];
        return (member.exists, member.isSteward, member.shares, member.joinedAt);
    }

    function getMemberCount() external view returns (uint256) {
        return LibDAOStorage.daoStorage().memberCount;
    }

    function getStewards() external view returns (address[] memory) {
        return LibDAOStorage.daoStorage().stewards;
    }

    function isInvestorWhitelisted(address investor) external view returns (bool) {
        return LibDAOStorage.daoStorage().investorWhitelist[investor];
    }

    function isProposerWhitelisted(address proposer) external view returns (bool) {
        return LibDAOStorage.daoStorage().proposerWhitelist[proposer];
    }
}
