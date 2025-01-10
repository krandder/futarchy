// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ProposalNFT.sol";

/**
 * @title ProposalManager
 * @notice Manages the minting and validation of NFTs for proposals.
 */
contract ProposalManager is ReentrancyGuard {
    ProposalNFT public immutable nft;
    address public owner;
    address public immutable proposerGuard;

    // Tracks the next NFT ID and how many are unused
    uint256 public nextTokenId = 1;
    uint256 public unusedNFTCount;
    mapping(uint256 => bool) public validNFTs;

    // Auction parameters
    uint256 public constant START_PRICE = 1000 ether;
    uint256 public constant MIN_PRICE = 0.1 ether;
    uint256 public constant DECAY_PER_DAY = 10;
    uint256 public constant MIN_UNUSED_NFTS = 5;
    uint256 public constant PROPOSAL_WINDOW = 3 days;

    // Auction state
    uint256 public auctionStart;
    uint256 public currentAuctionId;
    bool public auctionActive;

    // Represents which NFT is being used in a proposal
    struct NFTIdentifier {
        address nftContract;
        uint256 tokenId;
    }

    event AuctionStarted(uint256 indexed tokenId, uint256 startTime);
    event AuctionWon(uint256 indexed tokenId, address indexed winner, uint256 price);
    event NFTUsed(uint256 indexed tokenId);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyProposerGuard() {
        require(msg.sender == proposerGuard, "Not proposer guard");
        _;
    }

    constructor(address _nft, address _proposerGuard) {
        nft = ProposalNFT(_nft);
        proposerGuard = _proposerGuard;
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @notice Starts a new auction if none is active and the unused NFTs are below a threshold.
     */
    function startNewAuction() external {
        require(!auctionActive, "Auction active");
        require(unusedNFTCount < MIN_UNUSED_NFTS, "Enough unused NFTs");

        auctionActive = true;
        auctionStart = block.timestamp;
        currentAuctionId = nextTokenId;

        emit AuctionStarted(currentAuctionId, auctionStart);
    }

    /**
     * @return The current price of the NFT in the ongoing auction, decaying daily.
     */
    function getCurrentPrice() public view returns (uint256) {
        if (!auctionActive) return 0;
        uint256 elapsed = block.timestamp - auctionStart;
        uint256 daysElapsed = elapsed / 1 days;
        if (daysElapsed >= 10) return MIN_PRICE;

        uint256 decayFactor = DECAY_PER_DAY ** daysElapsed;
        uint256 price = START_PRICE / decayFactor;
        return price > MIN_PRICE ? price : MIN_PRICE;
    }

    /**
     * @notice Bids in the auction to mint an NFT.
     */
    function participateInAuction() external payable nonReentrant {
        require(auctionActive, "No active auction");
        uint256 price = getCurrentPrice();
        require(msg.value >= price, "Insufficient payment");

        nft.mint(msg.sender, currentAuctionId);
        nextTokenId++;
        unusedNFTCount++;
        validNFTs[currentAuctionId] = true;

        auctionActive = false;

        if (msg.value > price) {
            (bool success,) = msg.sender.call{ value: msg.value - price }("");
            require(success, "Refund failed");
        }

        emit AuctionWon(currentAuctionId, msg.sender, price);
    }

    /**
     * @notice Checks if an NFT is valid for a new proposal.
     */
    function validateProposal(uint256 tokenId) external view returns (bool) {
        require(validNFTs[tokenId], "NFT not valid");
        require(unusedNFTCount >= MIN_UNUSED_NFTS, "Not enough unused NFTs");
        require(nft.ownerOf(tokenId) == msg.sender, "Not NFT owner");
        return true;
    }

    /**
     * @notice Marks an NFT as used in a proposal.
     */
    function markNFTUsed(uint256 tokenId) external onlyProposerGuard {
        require(validNFTs[tokenId], "NFT not valid");
        validNFTs[tokenId] = false;
        unusedNFTCount--;
        emit NFTUsed(tokenId);
    }

    receive() external payable { }
}
