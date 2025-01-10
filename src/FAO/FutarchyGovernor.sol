// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IConditionalTokens.sol";

contract FutarchyGovernor {
    // Core contracts
    IConditionalTokens public immutable conditionalTokens;
    
    // The proposerGuard is a trusted contract that validates proposal configurations
    // before forwarding them to this governor. It must check that conditions,
    // oracles, and pools are properly set up.
    address public proposerGuard;
    
    struct Proposal {
        // NFT pointer (which NFT was used for this proposal)
        address nftContract;
        uint256 tokenId;
        
        // Gnosis CTF condition ID
        bytes32 conditionId;
        
        // Execution info
        address[] targets;
        uint256[] values;
        bytes[] data;
        
        // Additional metadata
        string memo;
        
        // Proposal status
        bool executed;
        bool exists;
    }
    
    // State
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    bool public hasActiveProposal;
    
    // Events
    event ProposerGuardUpdated(address indexed oldProposerGuard, address indexed newProposerGuard);
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed nftContract,
        uint256 indexed tokenId,
        bytes32 conditionId,
        address[] targets,
        uint256[] values,
        bytes[] data,
        string memo
    );
    event ProposalExecuted(uint256 indexed proposalId);
    
    constructor(
        address _conditionalTokens,
        address _initialProposerGuard
    ) {
        conditionalTokens = IConditionalTokens(_conditionalTokens);
        proposerGuard = _initialProposerGuard;
    }
    
    modifier onlyProposerGuard() {
        require(msg.sender == proposerGuard, "Not proposer guard");
        _;
    }
    
    // This can only be called through a proposal that has passed
    function updateProposerGuard(address _newProposerGuard) external {
        require(msg.sender == address(this), "Only through proposal");
        require(_newProposerGuard != address(0), "Zero address");
        
        emit ProposerGuardUpdated(proposerGuard, _newProposerGuard);
        proposerGuard = _newProposerGuard;
    }
    
    // Creates a new proposal; ensures there is no active proposal
    function createProposal(
        address _nftContract,
        uint256 _tokenId,
        bytes32 _conditionId,
        address[] calldata _targets,
        uint256[] calldata _values,
        bytes[] calldata _data,
        string calldata _memo
    ) 
        external 
        onlyProposerGuard 
        returns (uint256) 
    {
        require(!hasActiveProposal, "Active proposal exists");
        require(
            _targets.length == _values.length && 
            _values.length == _data.length,
            "Array lengths must match"
        );
        
        uint256 proposalId = proposalCount;
        proposals[proposalId] = Proposal({
            nftContract: _nftContract,
            tokenId: _tokenId,
            conditionId: _conditionId,
            targets: _targets,
            values: _values,
            data: _data,
            memo: _memo,
            executed: false,
            exists: true
        });
        
        hasActiveProposal = true;
        proposalCount++;
        
        emit ProposalCreated(
            proposalId,
            _nftContract,
            _tokenId,
            _conditionId,
            _targets,
            _values,
            _data,
            _memo
        );
        
        return proposalId;
    }
    
    // Executes a proposal only if it has passed in the conditional tokens framework
    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.exists, "Proposal does not exist");
        require(!proposal.executed, "Already executed");
        
        // Check resolution in the conditional tokens framework
        uint256[] memory payouts = conditionalTokens.payoutNumerators(proposal.conditionId);
        
        // Clear active proposal flag regardless of the outcome
        hasActiveProposal = false;
        
        // If the proposal fails, do nothing
        if (payouts[1] == 1) {
            return;
        }
        
        // Otherwise, require pass
        require(payouts[0] == 1, "Proposal status unclear");
        
        // Mark as executed before external calls
        proposal.executed = true;
        
        // Execute each action in the proposal
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(proposal.data[i]);
            require(success, "Execution failed");
        }
        
        emit ProposalExecuted(_proposalId);
    }
    
    // Returns all proposal details, including the NFT pointer
    function getProposal(uint256 _proposalId) external view returns (
        address nftContract,
        uint256 tokenId,
        bytes32 conditionId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory data,
        string memory memo,
        bool executed,
        bool exists
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.nftContract,
            proposal.tokenId,
            proposal.conditionId,
            proposal.targets,
            proposal.values,
            proposal.data,
            proposal.memo,
            proposal.executed,
            proposal.exists
        );
    }
    
    receive() external payable {}
}
