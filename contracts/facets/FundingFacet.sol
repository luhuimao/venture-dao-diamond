// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title FundingFacet
 * @notice Manages investment deposits, withdrawals, and funding distribution
 * @dev Migrated from FlexFunding and FundingPoolAdapter
 */

import {LibDAOStorage} from "../libraries/LibDAOStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract FundingFacet {
    // Custom Errors
    error ZeroAmount();
    error ProposalNotFound();
    error InvalidStatus();
    error NotWhitelisted();
    error CannotWithdraw();
    error NoContribution();
    error TransferFailed();
    error NotExecuted();
    error OnlyStewards();
    error NoFunds();
    error FeeTransferFailed();
    error NoBalance();
    
    event FundingDeposited(
        bytes32 indexed proposalId,
        address indexed investor,
        uint256 amount
    );
    event FundingWithdrawn(
        bytes32 indexed proposalId,
        address indexed investor,
        uint256 amount
    );
    event FundingDistributed(
        bytes32 indexed proposalId,
        uint256 totalAmount,
        uint256 feeAmount
    );

    /**
     * @notice Deposit funds for a proposal
     * @param proposalId Proposal ID
     */
    function deposit(bytes32 proposalId) external payable {
        if (msg.value == 0) revert ZeroAmount();
        
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        LibDAOStorage.Proposal storage proposal = ds.proposals[proposalId];
        LibDAOStorage.FundingData storage fundingData = ds.fundingRecords[proposalId];
        
        if (proposal.id == bytes32(0)) revert ProposalNotFound();
        if (proposal.status != LibDAOStorage.ProposalStatus.Active && proposal.status != LibDAOStorage.ProposalStatus.Passed) revert InvalidStatus();
        
        // Check investor whitelist
        if (!ds.investorWhitelist[msg.sender] && !ds.members[msg.sender].exists) revert NotWhitelisted();
        
        // Record contribution
        if (fundingData.contributions[msg.sender] == 0) {
            fundingData.contributors.push(msg.sender);
        }
        
        fundingData.contributions[msg.sender] += msg.value;
        fundingData.totalRaised += msg.value;
        
        emit FundingDeposited(proposalId, msg.sender, msg.value);
    }

    /**
     * @notice Withdraw funds from a failed proposal
     * @param proposalId Proposal ID
     */
    function withdraw(bytes32 proposalId) external {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        LibDAOStorage.Proposal storage proposal = ds.proposals[proposalId];
        LibDAOStorage.FundingData storage fundingData = ds.fundingRecords[proposalId];
        
        if (proposal.id == bytes32(0)) revert ProposalNotFound();
        if (proposal.status != LibDAOStorage.ProposalStatus.Failed && proposal.status != LibDAOStorage.ProposalStatus.Cancelled) revert CannotWithdraw();
        
        uint256 contribution = fundingData.contributions[msg.sender];
        if (contribution == 0) revert NoContribution();
        
        fundingData.contributions[msg.sender] = 0;
        fundingData.totalRaised -= contribution;
        
        // Transfer funds back
        (bool success, ) = msg.sender.call{value: contribution}("");
        if (!success) revert TransferFailed();
        
        emit FundingWithdrawn(proposalId, msg.sender, contribution);
    }

    /**
     * @notice Distribute funds after proposal execution  
     * @param proposalId Proposal ID
     */
    function distributeFunds(bytes32 proposalId) external {
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        LibDAOStorage.Proposal storage proposal = ds.proposals[proposalId];
        LibDAOStorage.FundingData storage fundingData = ds.fundingRecords[proposalId];
        
        require(proposal.id != bytes32(0), "FundingFacet: Proposal not found");
        if (proposal.status != LibDAOStorage.ProposalStatus.Executed) revert NotExecuted();
        if (!ds.members[msg.sender].isSteward) revert OnlyStewards();
        
        uint256 totalRaised = fundingData.totalRaised;
        if (totalRaised == 0) revert NoFunds();
        
        // Calculate fees
        uint256 managementFee = ds.configuration[keccak256("MANAGEMENT_FEE")];
        if (managementFee == 0) managementFee = 200; // 2% default (in basis points)
        
        uint256 feeAmount = (totalRaised * managementFee) / 10000;
        uint256 netAmount = totalRaised - feeAmount;
        
        // Get fee recipient
        address feeRecipient = ds.addressConfiguration[keccak256("FEE_RECIPIENT")];
        if (feeRecipient == address(0)) feeRecipient = ds.creator;
        
        // Transfer fee
        if (feeAmount > 0) {
            (bool feeSuccess, ) = feeRecipient.call{value: feeAmount}("");
            if (!feeSuccess) revert FeeTransferFailed();
        }
        
        // Transfer net amount to proposer or designated recipient
        address recipient = ds.addressConfiguration[
            keccak256(abi.encodePacked("RECIPIENT_", proposalId))
        ];
        if (recipient == address(0)) recipient = proposal.proposer;
        
        (bool success, ) = recipient.call{value: netAmount}("");
        if (!success) revert TransferFailed();
        
        fundingData.totalRaised = 0;
        
        emit FundingDistributed(proposalId, netAmount, feeAmount);
    }

    // View functions
    function getFundingInfo(bytes32 proposalId) external view returns (
        uint256 totalRaised,
        uint256 targetAmount,
        uint256 contributorCount
    ) {
        LibDAOStorage.FundingData storage fundingData = 
            LibDAOStorage.daoStorage().fundingRecords[proposalId];
        
        return (
            fundingData.totalRaised,
            fundingData.targetAmount,
            fundingData.contributors.length
        );
    }

    function getContribution(
        bytes32 proposalId,
        address contributor
    ) external view returns (uint256) {
        return LibDAOStorage.daoStorage()
            .fundingRecords[proposalId]
            .contributions[contributor];
    }

    function getContributors(bytes32 proposalId) external view returns (address[] memory) {
        return LibDAOStorage.daoStorage().fundingRecords[proposalId].contributors;
    }

    /**
     * @notice Get contract balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Emergency withdraw (owner only)
     */
    function emergencyWithdraw() external {
        LibDiamond.enforceIsContractOwner();
        
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoBalance();
        
        (bool success, ) = LibDiamond.contractOwner().call{value: balance}("");
        require(success, "FundingFacet: Transfer failed");
    }

    receive() external payable {}
}
