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
        require(msg.value > 0, "FundingFacet: Zero amount");
        
        LibDAOStorage.DAOStorage storage ds = LibDAOStorage.daoStorage();
        LibDAOStorage.Proposal storage proposal = ds.proposals[proposalId];
        LibDAOStorage.FundingData storage fundingData = ds.fundingRecords[proposalId];
        
        require(proposal.id != bytes32(0), "FundingFacet: Proposal not found");
        require(
            proposal.status == LibDAOStorage.ProposalStatus.Active ||
            proposal.status == LibDAOStorage.ProposalStatus.Passed,
            "FundingFacet: Invalid status"
        );
        
        // Check investor whitelist
        require(
            ds.investorWhitelist[msg.sender] || 
            ds.members[msg.sender].exists,
            "FundingFacet: Not whitelisted"
        );
        
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
        
        require(proposal.id != bytes32(0), "FundingFacet: Proposal not found");
        require(
            proposal.status == LibDAOStorage.ProposalStatus.Failed ||
            proposal.status == LibDAOStorage.ProposalStatus.Cancelled,
            "FundingFacet: Cannot withdraw"
        );
        
        uint256 contribution = fundingData.contributions[msg.sender];
        require(contribution > 0, "FundingFacet: No contribution");
        
        fundingData.contributions[msg.sender] = 0;
        fundingData.totalRaised -= contribution;
        
        // Transfer funds back
        (bool success, ) = msg.sender.call{value: contribution}("");
        require(success, "FundingFacet: Transfer failed");
        
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
        require(
            proposal.status == LibDAOStorage.ProposalStatus.Executed,
            "FundingFacet: Not executed"
        );
        require(
            ds.members[msg.sender].isSteward,
            "FundingFacet: Only stewards"
        );
        
        uint256 totalRaised = fundingData.totalRaised;
        require(totalRaised > 0, "FundingFacet: No funds");
        
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
            require(feeSuccess, "FundingFacet: Fee transfer failed");
        }
        
        // Transfer net amount to proposer or designated recipient
        address recipient = ds.addressConfiguration[
            keccak256(abi.encodePacked("RECIPIENT_", proposalId))
        ];
        if (recipient == address(0)) recipient = proposal.proposer;
        
        (bool success, ) = recipient.call{value: netAmount}("");
        require(success, "FundingFacet: Transfer failed");
        
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
        require(balance > 0, "FundingFacet: No balance");
        
        (bool success, ) = LibDiamond.contractOwner().call{value: balance}("");
        require(success, "FundingFacet: Transfer failed");
    }

    receive() external payable {}
}
