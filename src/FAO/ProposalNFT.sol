// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title ProposalNFT
 * @notice NFT contract for Futarchy proposals.
 */
contract ProposalNFT is ERC721 {
    address public owner;
    address public artist;
    address public minter;
    
    mapping(uint256 => string) public tokenMetadata;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event MinterUpdated(address indexed previousMinter, address indexed newMinter);
    event ArtistUpdated(address indexed previousArtist, address indexed newArtist);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(address _artist) ERC721("Futarchy Proposal", "FPROP") {
        owner = msg.sender;
        artist = _artist;
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    function setMinter(address newMinter) external onlyOwner {
        emit MinterUpdated(minter, newMinter);
        minter = newMinter;
    }
    
    function setArtist(address newArtist) external onlyOwner {
        emit ArtistUpdated(artist, newArtist);
        artist = newArtist;
    }
    
    /**
     * @notice Mints a new proposal NFT to `to`.
     */
    function mint(address to, uint256 tokenId) external {
        require(msg.sender == minter, "Only minter");
        _mint(to, tokenId);
    }
    
    /**
     * @notice Sets metadata for a given tokenId.
     */
    function setMetadata(uint256 tokenId, string calldata metadata) external {
        require(msg.sender == artist, "Only artist");
        require(_exists(tokenId), "Token doesn't exist");
        require(bytes(tokenMetadata[tokenId]).length == 0, "Metadata already set");
        tokenMetadata[tokenId] = metadata;
    }
}
