// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ConfigurationFacet
 * @notice Manages DAO configuration parameters
 * @dev Migrated from DaoRegistry configuration functions
 */

import {LibDAOStorage} from "../libraries/LibDAOStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract ConfigurationFacet {
    // Custom Errors
    error LengthMismatch();
    
    event ConfigurationUpdated(bytes32 indexed key, uint256 value);
    event AddressConfigurationUpdated(bytes32 indexed key, address value);
    event StringConfigurationUpdated(bytes32 indexed key, string value);

    /**
     * @notice Set a uint256 configuration value
     * @param key Configuration key
     * @param value Configuration value
     */
    function setConfiguration(bytes32 key, uint256 value) external {
        LibDiamond.enforceIsContractOwner();
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        ds.configuration[key] = value;
        emit ConfigurationUpdated(key, value);
    }

    /**
     * @notice Get a uint256 configuration value
     * @param key Configuration key
     * @return value Configuration value
     */
    function getConfiguration(bytes32 key) external view returns (uint256) {
        return LibDAOStorage.daoStorage().configuration[key];
    }

    /**
     * @notice Set an address configuration value
     * @param key Configuration key
     * @param value Configuration address
     */
    function setAddressConfiguration(bytes32 key, address value) external {
        LibDiamond.enforceIsContractOwner();
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        ds.addressConfiguration[key] = value;
        emit AddressConfigurationUpdated(key, value);
    }

    /**
     * @notice Get an address configuration value
     * @param key Configuration key
     * @return value Configuration address
     */
    function getAddressConfiguration(bytes32 key) external view returns (address) {
        return LibDAOStorage.daoStorage().addressConfiguration[key];
    }

    /**
     * @notice Set a string configuration value
     * @param key Configuration key
     * @param value Configuration string
     */
    function setStringConfiguration(bytes32 key, string calldata value) external {
        LibDiamond.enforceIsContractOwner();
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        ds.stringConfiguration[key] = value;
        emit StringConfigurationUpdated(key, value);
    }

    /**
     * @notice Get a string configuration value
     * @param key Configuration key
     * @return value Configuration string
     */
    function getStringConfiguration(bytes32 key) external view returns (string memory) {
        return LibDAOStorage.daoStorage().stringConfiguration[key];
    }

    /**
     * @notice Batch set multiple uint256 configurations
     * @param keys Array of configuration keys
     * @param values Array of configuration values
     */
    function batchSetConfiguration(
        bytes32[] calldata keys,
        uint256[] calldata values
    ) external {
        LibDiamond.enforceIsContractOwner();
        if (keys.length != values.length) revert LengthMismatch();
        
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        uint256 length = keys.length;
        
        for (uint256 i = 0; i < length;) {
            ds.configuration[keys[i]] = values[i];
            emit ConfigurationUpdated(keys[i], values[i]);
            unchecked { ++i; }
        }
    }

    /**
     * @notice Get DAO name
     */
    function daoName() external view returns (string memory) {
        return LibDAOStorage.daoStorage().name;
    }

    /**
     * @notice Get DAO type
     */
    function daoType() external view returns (string memory) {
        return LibDAOStorage.daoStorage().daoType;
    }

    /**
     * @notice Get DAO creator
     */
    function daoCreator() external view returns (address) {
        return LibDAOStorage.daoStorage().creator;
    }

    /**
     * @notice Get DAO creation timestamp
     */
    function createdAt() external view returns (uint256) {
        return LibDAOStorage.daoStorage().createdAt;
    }
}
