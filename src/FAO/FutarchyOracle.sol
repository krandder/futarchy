// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FutarchyRandomFailure.sol";
import "../interfaces/IConditionalTokens.sol";
import "../interfaces/IUniswapV3Pool.sol";

contract FutarchyOracle is Ownable {
    // Resolution states
    enum ResolutionState {
        PENDING,        // Initial state
        PRICE_CHECKED,  // TWAP checked, passed price check
        RANDOM_PENDING, // Random check requested
        RESOLVED       // Final resolution complete
    }
    
    struct Condition {
        IUniswapV3Pool passPool;
        IUniswapV3Pool failPool;
        uint256 minLiquidity;
        uint256 createdAt;
        ResolutionState state;
        bool priceCheckPassed;
    }
    
    // Core contracts
    FutarchyRandomFailure public immutable randomFailure;
    IConditionalTokens public immutable conditionalTokens;
    
    // Condition state
    mapping(bytes32 => Condition) public conditions;
    
    // Configuration
    uint32 public constant TWAP_PERIOD = 7 days;
    uint256 public constant PASS_THRESHOLD = 10100; // 1.01x in basis points
    
    // Events
    event ConditionInitialized(
        bytes32 indexed conditionId,
        address passPool,
        address failPool,
        uint256 minLiquidity
    );
    event PriceCheckCompleted(
        bytes32 indexed conditionId,
        bool passed,
        uint256 passPrice,
        uint256 failPrice
    );
    event RandomFailureRequested(bytes32 indexed conditionId);
    event ProposalResolved(bytes32 indexed conditionId, bool passed, string reason);
    event LowLiquidityFailure(
        bytes32 indexed conditionId,
        uint256 passLiquidity,
        uint256 failLiquidity
    );
    
    constructor(
        address _randomFailure,
        address _conditionalTokens
    ) Ownable(msg.sender) {
        randomFailure = FutarchyRandomFailure(_randomFailure);
        conditionalTokens = IConditionalTokens(_conditionalTokens);
    }
    
    function initializeCondition(
        bytes32 conditionId,
        address passPool,
        address failPool,
        uint256 minLiquidity
    ) external onlyOwner {
        require(conditions[conditionId].createdAt == 0, "Already initialized");
        
        conditions[conditionId] = Condition({
            passPool: IUniswapV3Pool(passPool),
            failPool: IUniswapV3Pool(failPool),
            minLiquidity: minLiquidity,
            createdAt: block.timestamp,
            state: ResolutionState.PENDING,
            priceCheckPassed: false
        });
        
        emit ConditionInitialized(conditionId, passPool, failPool, minLiquidity);
    }
    
    function checkLiquidity(bytes32 conditionId) public view returns (bool) {
        Condition storage condition = conditions[conditionId];
        return condition.passPool.liquidity() >= condition.minLiquidity && 
               condition.failPool.liquidity() >= condition.minLiquidity;
    }

    function checkLowLiquidityFailure(bytes32 conditionId) external {
        Condition storage condition = conditions[conditionId];
        require(condition.createdAt > 0, "Condition not initialized");
        require(condition.state == ResolutionState.PENDING, "Can only fail before price check");
        require(block.timestamp < condition.createdAt + TWAP_PERIOD, "Too late for liquidity check");
        require(!checkLiquidity(conditionId), "Sufficient liquidity");

        condition.state = ResolutionState.RESOLVED;
        
        uint256[] memory payouts = new uint256[](2);
        payouts[1] = 1; // Fail outcome
        conditionalTokens.reportPayouts(conditionId, payouts);
        
        emit LowLiquidityFailure(
            conditionId,
            condition.passPool.liquidity(),
            condition.failPool.liquidity()
        );
        emit ProposalResolved(conditionId, false, "Low liquidity");
    }
    
    function getTWAP(IUniswapV3Pool pool, uint256 createdAt) internal view returns (uint256) {
        require(
            block.timestamp >= createdAt + TWAP_PERIOD,
            "Oracle too young for TWAP"
        );

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = TWAP_PERIOD;
        secondsAgos[1] = 0;
        
        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);
        
        int56 tickAverage = (tickCumulatives[1] - tickCumulatives[0]) / int32(TWAP_PERIOD);
        return uint256(int256(tickAverage));
    }

    function performPriceCheck(bytes32 conditionId) external {
        Condition storage condition = conditions[conditionId];
        require(condition.createdAt > 0, "Condition not initialized");
        require(condition.state == ResolutionState.PENDING, "Invalid state");
        
        uint256 passPrice = getTWAP(condition.passPool, condition.createdAt);
        uint256 failPrice = getTWAP(condition.failPool, condition.createdAt);
        
        condition.priceCheckPassed = (passPrice * 10000) >= (failPrice * PASS_THRESHOLD);
        
        emit PriceCheckCompleted(conditionId, condition.priceCheckPassed, passPrice, failPrice);
        
        if (!condition.priceCheckPassed) {
            uint256[] memory payouts = new uint256[](2);
            payouts[1] = 1; // Fail outcome
            conditionalTokens.reportPayouts(conditionId, payouts);
            condition.state = ResolutionState.RESOLVED;
            emit ProposalResolved(conditionId, false, "Failed price check");
        } else {
            condition.state = ResolutionState.PRICE_CHECKED;
        }
    }

    function requestRandomCheck(bytes32 conditionId) external {
        Condition storage condition = conditions[conditionId];
        require(condition.createdAt > 0, "Condition not initialized");
        require(condition.state == ResolutionState.PRICE_CHECKED, "Invalid state");
        
        randomFailure.requestRandomFailureCheck(conditionId);
        condition.state = ResolutionState.RANDOM_PENDING;
        emit RandomFailureRequested(conditionId);
    }
    
    function completeResolution(bytes32 conditionId) external {
        Condition storage condition = conditions[conditionId];
        require(condition.createdAt > 0, "Condition not initialized");
        require(condition.state == ResolutionState.RANDOM_PENDING, "Invalid state");
        
        bool randomPassed = !randomFailure.shouldProposalFail(conditionId);
        
        uint256[] memory payouts = new uint256[](2);
        payouts[randomPassed ? 0 : 1] = 1;
        conditionalTokens.reportPayouts(conditionId, payouts);
        
        condition.state = ResolutionState.RESOLVED;
        emit ProposalResolved(conditionId, randomPassed, randomPassed ? "Passed" : "Random failure");
    }

    function getConditionState(bytes32 conditionId) external view returns (
        ResolutionState state,
        bool priceCheckPassed,
        bool hasLiquidity,
        uint256 createdAt,
        uint256 minLiquidity
    ) {
        Condition storage condition = conditions[conditionId];
        return (
            condition.state,
            condition.priceCheckPassed,
            checkLiquidity(conditionId),
            condition.createdAt,
            condition.minLiquidity
        );
    }
}