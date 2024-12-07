// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IWrapped1155Factory.sol";

contract MockWrapped1155Factory is IWrapped1155Factory {
    mapping(bytes32 => address) public wrappedTokens;

    function requireWrapped1155(
        IERC20 token,
        uint256 tokenId,
        bytes calldata  // data parameter removed
    ) external returns (address) {
        bytes32 key = keccak256(abi.encodePacked(token, tokenId));
        if (wrappedTokens[key] == address(0)) {
            wrappedTokens[key] = address(uint160(uint256(key)));
        }
        return wrappedTokens[key];
    }

    function getWrapped1155(
        IERC20 token,
        uint256 tokenId,
        bytes calldata  // data parameter removed
    ) external view returns (address) {
        bytes32 key = keccak256(abi.encodePacked(token, tokenId));
        return wrappedTokens[key];
    }

    function unwrap(
        IERC20 token,
        uint256 tokenId,
        uint256 amount,
        address recipient,
        bytes calldata  // data parameter removed
    ) external {
        // Mock implementation - no actual unwrapping needed for tests
    }
}