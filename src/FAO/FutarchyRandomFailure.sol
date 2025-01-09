// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract FutarchyRandomFailure is VRFConsumerBaseV2, Ownable {
    event RandomnessRequested(uint256 requestId, bytes32 proposalId);
    event RandomnessReceived(uint256 requestId, uint256 randomness);
    event ProposalFailed(bytes32 proposalId, bool randomFailure);

    VRFCoordinatorV2Interface immutable COORDINATOR;
    
    // Chainlink VRF subscription ID
    uint64 immutable subscriptionId;
    
    // The gas lane to use (varies by network)
    bytes32 immutable keyHash;
    
    // Number for 5% probability (5% of type(uint256).max)
    uint256 constant FAILURE_THRESHOLD = type(uint256).max / 20;
    
    // Mapping to store pending randomness requests
    mapping(uint256 => bytes32) public requestToProposal;
    
    // Random results cache
    mapping(bytes32 => uint256) public proposalRandomness;

    constructor(
        address coordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(coordinator) Ownable(msg.sender) {
        COORDINATOR = VRFCoordinatorV2Interface(coordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
    }

    /**
     * @notice Request random number for a proposal
     * @param proposalId The ID of the proposal to check
     */
    function requestRandomFailureCheck(bytes32 proposalId) external onlyOwner returns (uint256 requestId) {
        // Request randomness from Chainlink VRF
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            3, // 3 block confirmations
            100000, // gas limit
            1 // number of random words
        );
        
        requestToProposal[requestId] = proposalId;
        emit RandomnessRequested(requestId, proposalId);
    }

    /**
     * @notice Callback function used by VRF Coordinator to return the random number
     * @param requestId The request ID
     * @param randomWords Array of random numbers
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 randomness = randomWords[0];
        bytes32 proposalId = requestToProposal[requestId];
        
        proposalRandomness[proposalId] = randomness;
        emit RandomnessReceived(requestId, randomness);
        
        // Check if proposal should randomly fail (5% chance)
        bool shouldFail = randomness < FAILURE_THRESHOLD;
        
        if (shouldFail) {
            emit ProposalFailed(proposalId, true);
        }
    }

    /**
     * @notice Check if a proposal should randomly fail
     * @param proposalId The ID of the proposal to check
     * @return True if randomness is below failure threshold
     */
    function shouldProposalFail(bytes32 proposalId) external view returns (bool) {
        uint256 randomness = proposalRandomness[proposalId];
        require(randomness != 0, "Randomness not yet available");
        return randomness < FAILURE_THRESHOLD;
    }
}