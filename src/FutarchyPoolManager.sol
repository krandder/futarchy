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

    // Optional security features
    bool public useEnhancedSecurity;
    address public admin;

    // Registry of allowed splits (for enhanced security)
    // Key: keccak256(abi.encodePacked(baseToken, yesToken, noToken))
    mapping(bytes32 => bool) public allowedSplits;

    // Storing condition pools
    mapping(bytes32 => ConditionalPools) public conditionPools;
    
    struct ConditionalPools {
        address yesPool;
        address noPool;
        bool isActive;
    }

    // Custom errors
    error ConditionAlreadyActive();
    error ConditionNotActive();
    error ConditionNotSettled();
    error TransferFailed();
    error Unauthorized();
    error SplitNotAllowed();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    constructor(
        address _ctfAdapter,
        address _balancerWrapper,
        address _outcomeToken,
        address _moneyToken,
        bool _useEnhancedSecurity,
        address _admin
    ) {
        ctfAdapter = ICTFAdapter(_ctfAdapter);
        balancerWrapper = IBalancerPoolWrapper(_balancerWrapper);
        outcomeToken = IERC20(_outcomeToken);
        moneyToken = IERC20(_moneyToken);
        useEnhancedSecurity = _useEnhancedSecurity;
        admin = _admin;
    }

    // Allows the admin to register an allowed split
    // This restricts which token triples can be formed during splits if enhanced security is on.
    function addAllowedSplit(
        address baseToken,
        address yesToken,
        address noToken
    ) external onlyAdmin {
        bytes32 key = keccak256(abi.encodePacked(baseToken, yesToken, noToken));
        allowedSplits[key] = true;
    }

    function _checkAllowedSplit(address baseTok, address yesTok, address noTok) internal view {
        bytes32 key = keccak256(abi.encodePacked(baseTok, yesTok, noTok));
        if (!allowedSplits[key]) {
            revert SplitNotAllowed();
        }
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

        // Add liquidity to the newly created pool
        balancerWrapper.addLiquidity(basePool, outcomeAmount, moneyAmount);

        return basePool;
    }

    function splitOnCondition(
        bytes32 conditionId,
        uint256 baseAmount
    ) external returns (address yesPool, address noPool) {
        if (conditionPools[conditionId].isActive) revert ConditionAlreadyActive();

        // Remove liquidity from base pool
        (uint256 outcomeAmount, uint256 moneyAmount) = balancerWrapper.removeLiquidity(
            basePool,
            baseAmount
        );

        // Approve ctfAdapter to spend the tokens
        outcomeToken.approve(address(ctfAdapter), outcomeAmount);
        moneyToken.approve(address(ctfAdapter), moneyAmount);

        // Split both tokens into conditional tokens (assuming binary outcome)
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

        // If enhanced security is enabled, verify that these splits are allowed
        if (useEnhancedSecurity) {
            // Check splits for outcomeToken
            _checkAllowedSplit(address(outcomeToken), outcomeConditionals[1], outcomeConditionals[0]);
            // Check splits for moneyToken
            _checkAllowedSplit(address(moneyToken), moneyConditionals[1], moneyConditionals[0]);
        }

        // Create YES pool (outcomeConditional[1]/moneyConditional[1])
        yesPool = balancerWrapper.createPool(
            outcomeConditionals[1],
            moneyConditionals[1],
            500000 // 50-50 weight
        );

        // Create NO pool (outcomeConditional[0]/moneyConditional[0])
        noPool = balancerWrapper.createPool(
            outcomeConditionals[0],
            moneyConditionals[0],
            500000 // 50-50 weight
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

        // Remove liquidity from winning pool. 
        // In a real scenario, you'd determine which is the winning pool after settlement.
        // For illustration, let's assume 'yesPool' is winning.
        (uint256 outcomeAmount, uint256 moneyAmount) = balancerWrapper.removeLiquidity(
            pools.yesPool,
            type(uint256).max // Remove all liquidity
        );

        uint256[] memory amounts = new uint256[](2);

        // Redeem outcomeToken positions
        amounts[0] = 0; // NO
        amounts[1] = outcomeAmount; // YES
        uint256 outcomeRedeemed = ctfAdapter.redeemPositions(
            outcomeToken,
            conditionId,
            amounts,
            2
        );

        // Redeem moneyToken positions
        amounts[0] = 0; // NO
        amounts[1] = moneyAmount; // YES
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
