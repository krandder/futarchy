// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IConditionalTokens.sol";
import "./interfaces/IWrapped1155Factory.sol";

/// @title Gnosis CTF Adapter
/// @author Futarchy Project Team
/// @notice Provides a simplified interface for splitting ERC20 tokens into conditional outcome tokens
/// @dev Integrates with Gnosis Conditional Token Framework (CTF) and Wrapped1155Factory to handle
/// the conversion between ERC20 tokens and conditional tokens. All operations are permissionless.
/// @custom:security-contact security@futarchy.com
contract GnosisCTFAdapter {
    using SafeERC20 for IERC20;

    /// @notice Reference to Gnosis CTF contract
    IConditionalTokens public immutable conditionalTokens;
    /// @notice Reference to the factory that wraps ERC1155 tokens as ERC20
    IWrapped1155Factory public immutable wrapped1155Factory;

    // Custom errors
    /// @notice Thrown when outcome count is invalid (must be > 1)
    error InvalidOutcomeCount(uint256 count);
    /// @notice Thrown when ERC1155 to ERC20 wrapping fails
    error WrappingFailed();
    /// @notice Thrown when position redemption fails
    error RedemptionFailed();
    /// @notice Thrown when condition has not been resolved
    error ConditionNotResolved();

    /// @notice Creates a new adapter instance
    /// @param _conditionalTokens Address of the Gnosis CTF contract
    /// @param _wrapped1155Factory Address of the Wrapped1155Factory contract
    constructor(address _conditionalTokens, address _wrapped1155Factory) {
        conditionalTokens = IConditionalTokens(_conditionalTokens);
        wrapped1155Factory = IWrapped1155Factory(_wrapped1155Factory);
    }

    /// @notice Splits ERC20 tokens into conditional outcome tokens
    /// @param collateralToken The ERC20 token to split
    /// @param conditionId The condition identifier from Gnosis CTF
    /// @param amount Amount of collateral tokens to split
    /// @param outcomeCount Number of outcomes in the condition (minimum 2)
    /// @return wrappedTokens Array of ERC20 addresses representing conditional tokens
    /// @dev For binary conditions, returns [NO token, YES token]
    /// @dev For n outcomes, returns [outcome A token, outcome B token, ...]
    function splitCollateralTokens(
        IERC20 collateralToken,
        bytes32 conditionId,
        uint256 amount,
        uint256 outcomeCount
    ) external returns (address[] memory wrappedTokens) {
        if (outcomeCount <= 1) revert InvalidOutcomeCount(outcomeCount);
        
        // Create partition array [1, 2, 4, 8, ...] for outcomes
        uint256[] memory partition = new uint256[](outcomeCount);
        for(uint256 i = 0; i < outcomeCount; i++) {
            partition[i] = 1 << i;  // 2^i
        }

        // Transfer and approve collateral
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        collateralToken.approve(address(conditionalTokens), amount);

        // Split into position tokens
        conditionalTokens.splitPosition(
            collateralToken,
            bytes32(0),
            conditionId,
            partition,
            amount
        );

        // Create and wrap tokens for each outcome
        wrappedTokens = new address[](outcomeCount);
        for (uint256 i = 0; i < outcomeCount; i++) {
            uint256 positionId = conditionalTokens.getPositionId(
                collateralToken,
                conditionalTokens.getCollectionId(bytes32(0), conditionId, partition[i])
            );
            
            bytes memory tokenData = abi.encodePacked(
                _generateTokenName(collateralToken, conditionId, i, outcomeCount),
                _generateTokenSymbol(collateralToken, conditionId, i, outcomeCount),
                hex"12"  // 18 decimals
            );

            wrappedTokens[i] = address(wrapped1155Factory.requireWrapped1155(
                conditionalTokens,
                positionId,
                tokenData
            ));
        }

        return wrappedTokens;
    }

   /// @notice Redeems conditional tokens for collateral tokens after condition resolution
   /// @param collateralToken The original ERC20 collateral token
   /// @param conditionId The condition identifier from Gnosis CTF
   /// @param amounts Array of amounts to redeem for each outcome position
   /// @param outcomeCount Number of outcomes in the condition
   /// @return payoutAmount Total amount of collateral tokens received from redemption
   /// @dev Unwraps ERC20 positions back to ERC1155 and redeems through CTF
   function redeemPositions(
       IERC20 collateralToken,
       bytes32 conditionId,
       uint256[] calldata amounts,
       uint256 outcomeCount
   ) external returns (uint256 payoutAmount) {
       // Check if condition is resolved
       uint256 payoutDenominator = conditionalTokens.payoutDenominator(conditionId);
       if(payoutDenominator == 0) revert ConditionNotResolved();

       uint256[] memory partition = new uint256[](outcomeCount);
       for(uint256 i = 0; i < outcomeCount; i++) {
           partition[i] = 1 << i;

           if(amounts[i] > 0) {
               // Get position info
               uint256 positionId = conditionalTokens.getPositionId(
                   collateralToken,
                   conditionalTokens.getCollectionId(bytes32(0), conditionId, partition[i])
               );

               // Unwrap ERC20 back to ERC1155
               try wrapped1155Factory.unwrap(
                   conditionalTokens,
                   positionId,
                   amounts[i],
                   address(this),
                   ""
               ) {} catch {
                   revert WrappingFailed();
               }
           }
       }

       // Redeem all positions
       uint256[] memory indexSets = new uint256[](outcomeCount);
       for(uint256 i = 0; i < outcomeCount; i++) {
           indexSets[i] = partition[i];
       }
       
       try conditionalTokens.redeemPositions(
           collateralToken,
           bytes32(0),
           conditionId,
           indexSets
       ) {} catch {
           revert RedemptionFailed();
       }

       // Transfer redeemed collateral back to user
       payoutAmount = collateralToken.balanceOf(address(this));
       if(payoutAmount > 0) {
           collateralToken.safeTransfer(msg.sender, payoutAmount);
       }

       return payoutAmount;
   }

   /// @notice View function to get wrapped token addresses without performing splits
   /// @param collateralToken The ERC20 token that would be split
   /// @param conditionId The condition identifier from Gnosis CTF
   /// @param outcomeCount Number of outcomes in the condition
   /// @return addresses Array of ERC20 addresses that would be created for the outcomes
   /// @dev Uses the same deterministic address calculation as actual splitting
   function getWrappedTokens(
       IERC20 collateralToken,
       bytes32 conditionId,
       uint256 outcomeCount
   ) external view returns (address[] memory addresses) {
       if (outcomeCount <= 1) revert InvalidOutcomeCount(outcomeCount);
       
       addresses = new address[](outcomeCount);
       for(uint256 i = 0; i < outcomeCount; i++) {
           uint256 partition = 1 << i;
           
           uint256 positionId = conditionalTokens.getPositionId(
               collateralToken,
               conditionalTokens.getCollectionId(bytes32(0), conditionId, partition)
           );
           
           bytes memory tokenData = abi.encodePacked(
               _generateTokenName(collateralToken, conditionId, i, outcomeCount),
               _generateTokenSymbol(collateralToken, conditionId, i, outcomeCount),
               hex"12"
           );

           addresses[i] = wrapped1155Factory.getWrapped1155(
               conditionalTokens,
               positionId,
               tokenData
           );
       }

       return addresses;
   }

   /// @notice Generates the full name for a conditional token
   /// @dev For binary conditions: "{BaseToken} Yes/No Position"
   /// @dev For multiple outcomes: "{BaseToken} Outcome A/B/C..."
   function _generateTokenName(
       IERC20 collateralToken,
       bytes32 conditionId,
       uint256 outcomeIndex,
       uint256 totalOutcomes
   ) internal view returns (bytes32) {
       string memory baseToken = IERC20(collateralToken).name();
       
       if(totalOutcomes == 2) {
           return outcomeIndex == 1 ? 
               string.concat(baseToken, " Yes Position") : 
               string.concat(baseToken, " No Position");
       }
       
       return string.concat(
           baseToken,
           " Outcome ",
           string(bytes1(65 + outcomeIndex))
       );
   }

   /// @notice Generates the symbol for a conditional token
   /// @dev For binary conditions: "{BaseSymbol}-Y/N"
   /// @dev For multiple outcomes: "{BaseSymbol}-A/B/C..."
   function _generateTokenSymbol(
       IERC20 collateralToken,
       bytes32 conditionId,
       uint256 outcomeIndex,
       uint256 totalOutcomes
   ) internal view returns (bytes32) {
       string memory baseSymbol = IERC20(collateralToken).symbol();
       
       if(totalOutcomes == 2) {
           return outcomeIndex == 1 ? 
               string.concat(baseSymbol, "-Y") : 
               string.concat(baseSymbol, "-N");
       }
       
       return string.concat(
           baseSymbol,
           "-",
           string(bytes1(65 + outcomeIndex))
       );
   }
}
