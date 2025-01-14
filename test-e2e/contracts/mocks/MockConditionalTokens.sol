// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockConditionalTokens {
    struct Condition {
        address oracle;
        bytes32 questionId;
        uint256 outcomeSlotCount;
        bool isResolved;
        uint256 payoutDenominator;
    }

    mapping(bytes32 => Condition) public conditions;

    event ConditionPreparation(
        bytes32 indexed conditionId,
        address indexed oracle,
        bytes32 indexed questionId,
        uint256 outcomeSlotCount
    );

    event ConditionResolution(
        bytes32 indexed conditionId,
        uint256 payoutDenominator
    );

    function prepareCondition(
        address oracle,
        bytes32 conditionId,
        uint256 outcomeSlotCount
    ) external {
        require(outcomeSlotCount > 1, "Invalid outcome slot count");
        
        conditions[conditionId] = Condition({
            oracle: oracle,
            questionId: conditionId,
            outcomeSlotCount: outcomeSlotCount,
            isResolved: false,
            payoutDenominator: 0
        });

        emit ConditionPreparation(
            conditionId,
            oracle,
            conditionId,
            outcomeSlotCount
        );
    }

    function setPayoutDenominator(
        bytes32 conditionId,
        uint256 denominator
    ) external {
        require(!conditions[conditionId].isResolved, "Already resolved");
        require(denominator > 0, "Invalid denominator");

        conditions[conditionId].isResolved = true;
        conditions[conditionId].payoutDenominator = denominator;

        emit ConditionResolution(conditionId, denominator);
    }

    function getConditionResolution(bytes32 conditionId)
        external
        view
        returns (bool isResolved, uint256 payoutDenominator)
    {
        Condition storage condition = conditions[conditionId];
        return (condition.isResolved, condition.payoutDenominator);
    }
} 