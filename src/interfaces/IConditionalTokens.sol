// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IConditionalTokens {
    function prepareCondition(address oracle, bytes32 questionId, uint outcomeSlotCount) external;
    
    function getConditionId(address oracle, bytes32 questionId, uint outcomeSlotCount) external pure returns (bytes32);
    
    function getOutcomeSlotCount(bytes32 conditionId) external view returns (uint);
    
    function splitPosition(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint[] calldata partition,
        uint amount
    ) external;
    
    function mergePositions(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint[] calldata partition,
        uint amount
    ) external;
    
    function redeemPositions(
        IERC20 collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint[] calldata indexSets
    ) external;

    function getPositionId(IERC20 collateralToken, bytes32 collectionId) external pure returns (uint);
    
    function getCollectionId(
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint indexSet
    ) external view returns (bytes32);
    
    function payoutDenominator(bytes32 conditionId) external view returns (uint);

    function payoutNumerators(bytes32 conditionId) external view returns (uint256[] memory);
    
    function reportPayouts(bytes32 conditionId, uint256[] calldata payouts) external;

    function conditions(bytes32 conditionId) external view returns (
        address oracle,
        bytes32 questionId,
        uint outcomeSlotCount,
        uint payoutNumerator
    );
}