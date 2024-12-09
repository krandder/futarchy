// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ICTFAdapter.sol";
import "./interfaces/IBalancerPoolWrapper.sol";

contract FutarchyPoolManager {
    using SafeERC20 for IERC20;

    // Core components
    ICTFAdapter public immutable ctfAdapter;
    IBalancerPoolWrapper public immutable balancerWrapper;
    
    // Base assets
    IERC20 public immutable outcomeToken;
    IERC20 public immutable moneyToken;
    
    // Pool state
    address public basePool;
    mapping(bytes32 => ConditionalPools) public conditionPools;
    
    struct ConditionalPools {
        address yesPool;
        address noPool;
        bool isActive;
    }

    error ConditionAlreadyActive();
    error ConditionNotActive();
    error ConditionNotSettled();
    error TransferFailed();

    constructor(
        address _ctfAdapter,
        address _balancerWrapper,
        address _outcomeToken,
        address _moneyToken
    ) {
        ctfAdapter = ICTFAdapter(_ctfAdapter);
        balancerWrapper = IBalancerPoolWrapper(_balancerWrapper);
        outcomeToken = IERC20(_outcomeToken);
        moneyToken = IERC20(_moneyToken);
    }

    function createBasePool(
        uint256 outcomeAmount,
        uint256 moneyAmount,
        uint256 weight
    ) external returns (address) {
        // Transfer tokens to this contract
        outcomeToken.safeTransferFrom(msg.sender, address(this), outcomeAmount);
        moneyToken.safeTransferFrom(msg.sender, address(this), moneyAmount);

        // Approve balancer wrapper to spend them
        outcomeToken.approve(address(balancerWrapper), outcomeAmount);
        moneyToken.approve(address(balancerWrapper), moneyAmount);

        // Create the base pool
        basePool = balancerWrapper.createPool(
            address(outcomeToken),
            address(moneyToken),
            weight
        );

        // Now add liquidity to the newly created pool so that the tokens move into it
        balancerWrapper.addLiquidity(
            basePool,
            outcomeAmount,
            moneyAmount
        );

        return basePool;
    }

    function splitOnCondition(
        bytes32 conditionId,
        uint256 baseAmount
    ) external returns (address yesPool, address noPool) {
        if (conditionPools[conditionId].isActive) revert ConditionAlreadyActive();

        // Get LP tokens from base pool
        (uint256 outcomeAmount, uint256 moneyAmount) = balancerWrapper.removeLiquidity(
            basePool,
            baseAmount
        );

        // Approve ctfAdapter to spend the tokens
        outcomeToken.approve(address(ctfAdapter), outcomeAmount);
        moneyToken.approve(address(ctfAdapter), moneyAmount);

        // Now split both tokens into conditional tokens
        address[] memory outcomeConditionals = ctfAdapter.splitCollateralTokens(
            outcomeToken,
            conditionId,
            outcomeAmount,
            2
        );

        address[] memory moneyConditionals = ctfAdapter.splitCollateralTokens(
            moneyToken,
            conditionId,
            moneyAmount,
            2
        );

        // Create YES pool (outcomeConditional[1]/moneyConditional[1])
        yesPool = balancerWrapper.createPool(
            outcomeConditionals[1],  // YES outcome token
            moneyConditionals[1],    // YES money token
            500000  // 50-50 weight
        );

        // Create NO pool (outcomeConditional[0]/moneyConditional[0])
        noPool = balancerWrapper.createPool(
            outcomeConditionals[0],  // NO outcome token
            moneyConditionals[0],    // NO money token
            500000  // 50-50 weight
        );

        // Store pools
        conditionPools[conditionId] = ConditionalPools({
            yesPool: yesPool,
            noPool: noPool,
            isActive: true
        });

        return (yesPool, noPool);
    }

    function mergeAfterSettlement(
        bytes32 conditionId
    ) external {
        ConditionalPools storage pools = conditionPools[conditionId];
        if (!pools.isActive) revert ConditionNotActive();

        // Remove liquidity from winning pool (determined by settlement)
        (uint256 outcomeAmount, uint256 moneyAmount) = balancerWrapper.removeLiquidity(
            pools.yesPool,
            type(uint256).max  // Remove all liquidity
        );

        // Redeem conditional tokens for base tokens
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;          // NO amount
        amounts[1] = outcomeAmount;  // YES amount
        
        uint256 outcomeRedeemed = ctfAdapter.redeemPositions(
            outcomeToken,
            conditionId,
            amounts,
            2
        );

        amounts[0] = 0;        // NO amount
        amounts[1] = moneyAmount;  // YES amount
        
        uint256 moneyRedeemed = ctfAdapter.redeemPositions(
            moneyToken,
            conditionId,
            amounts,
            2
        );

        // Add liquidity back to base pool
        outcomeToken.approve(address(balancerWrapper), outcomeRedeemed);
        moneyToken.approve(address(balancerWrapper), moneyRedeemed);
        
        balancerWrapper.addLiquidity(
            basePool,
            outcomeRedeemed,
            moneyRedeemed
        );

        // Clear state
        delete conditionPools[conditionId];
    }
}