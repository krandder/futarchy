// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ProposalNFT.sol";
import "../interfaces/IConditionalTokens.sol";
import "../interfaces/IWrapped1155Factory.sol";
import "./FutarchyOracle.sol";
import "./FutarchyGovernor.sol";
import "./ProposalManager.sol";

contract FutarchyProposerGuard is Ownable {
    IConditionalTokens public immutable conditionalTokens;
    IWrapped1155Factory public immutable wrapped1155Factory;
    FutarchyGovernor public immutable governor;
    uint256 public immutable minimumOracleLiquidity;
    ProposalManager public immutable proposalManager;

    address public proposer;

    event ProposerUpdated(address indexed oldProposer, address indexed newProposer);
    event ProposalValidated(bytes32 indexed conditionId, address indexed passPool, address indexed failPool);

    modifier onlyProposer() {
        require(msg.sender == proposer, "Not proposer");
        _;
    }

    constructor(
        address _conditionalTokens,
        address _wrapped1155Factory,
        address payable _governor,
        uint256 _minimumOracleLiquidity,
        address _initialProposer,
        address payable _proposalManager
    ) Ownable(msg.sender) {
        conditionalTokens = IConditionalTokens(_conditionalTokens);
        wrapped1155Factory = IWrapped1155Factory(_wrapped1155Factory);
        governor = FutarchyGovernor(_governor);
        minimumOracleLiquidity = _minimumOracleLiquidity;
        proposer = _initialProposer;
        proposalManager = ProposalManager(_proposalManager);
    }

    function updateProposer(address _newProposer) external onlyOwner {
        require(_newProposer != address(0), "Zero address");
        emit ProposerUpdated(proposer, _newProposer);
        proposer = _newProposer;
    }

    function verifyPools(
        bytes32 conditionId,
        IERC20 outcomeToken,
        IERC20 currencyToken,
        address yesPool,
        address noPool
    ) internal view returns (bool) {
        require(conditionalTokens.getOutcomeSlotCount(conditionId) == 2, "Must have exactly 2 outcomes");

        bytes32 yesCollection = conditionalTokens.getCollectionId(bytes32(0), conditionId, 1);
        bytes32 noCollection = conditionalTokens.getCollectionId(bytes32(0), conditionId, 2);

        uint256 yesOutcomePositionId = conditionalTokens.getPositionId(IERC20(address(outcomeToken)), yesCollection);
        uint256 noOutcomePositionId = conditionalTokens.getPositionId(IERC20(address(outcomeToken)), noCollection);
        uint256 yesCurrencyPositionId = conditionalTokens.getPositionId(IERC20(address(currencyToken)), yesCollection);
        uint256 noCurrencyPositionId = conditionalTokens.getPositionId(IERC20(address(currencyToken)), noCollection);

        address yesOutcomeToken =
            wrapped1155Factory.getWrapped1155(IERC20(address(conditionalTokens)), yesOutcomePositionId, "");
        address noOutcomeToken =
            wrapped1155Factory.getWrapped1155(IERC20(address(conditionalTokens)), noOutcomePositionId, "");
        address yesCurrencyToken =
            wrapped1155Factory.getWrapped1155(IERC20(address(conditionalTokens)), yesCurrencyPositionId, "");
        address noCurrencyToken =
            wrapped1155Factory.getWrapped1155(IERC20(address(conditionalTokens)), noCurrencyPositionId, "");

        IUniswapV3Pool yesPoolContract = IUniswapV3Pool(yesPool);
        IUniswapV3Pool noPoolContract = IUniswapV3Pool(noPool);

        address yesToken0 = yesPoolContract.token0();
        address yesToken1 = yesPoolContract.token1();
        address noToken0 = noPoolContract.token0();
        address noToken1 = noPoolContract.token1();

        require(
            (yesToken0 == yesOutcomeToken && yesToken1 == yesCurrencyToken)
                || (yesToken1 == yesOutcomeToken && yesToken0 == yesCurrencyToken),
            "Yes pool tokens mismatch"
        );
        require(
            (noToken0 == noOutcomeToken && noToken1 == noCurrencyToken)
                || (noToken1 == noOutcomeToken && noToken0 == noCurrencyToken),
            "No pool tokens mismatch"
        );

        return true;
    }

    function verifyOracleSetup(FutarchyOracle oracle, bytes32 conditionId, IERC20 outcomeToken, IERC20 currencyToken)
        internal
        view
        returns (bool)
    {
        (address oracleAddress,,,) = conditionalTokens.conditions(conditionId);
        require(oracleAddress == address(oracle), "Wrong oracle");

        (
            IUniswapV3Pool passPool,
            IUniswapV3Pool failPool,
            uint256 minLiquidity,
            uint256 createdAt,
            FutarchyOracle.ResolutionState state,
            bool priceCheckPassed
        ) = oracle.conditions(conditionId);
        require(address(passPool) != address(0), "Condition not initialized");

        verifyPools(conditionId, outcomeToken, currencyToken, address(passPool), address(failPool));

        (uint160 yesSqrtPrice,,,,,,) = passPool.slot0();
        (uint160 noSqrtPrice,,,,,,) = failPool.slot0();
        require(yesSqrtPrice == noSqrtPrice, "Initial prices must match");

        require(minLiquidity >= minimumOracleLiquidity, "Insufficient min liquidity");

        return true;
    }

    function createProposal(
        uint256 nftId,
        address nftContract,
        bytes32 conditionId,
        FutarchyOracle oracle,
        IERC20 outcomeToken,
        IERC20 currencyToken,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata data,
        string calldata memo
    ) external onlyProposer returns (uint256) {
        require(proposalManager.validateProposal(nftId), "Invalid NFT");
        require(verifyOracleSetup(oracle, conditionId, outcomeToken, currencyToken), "Invalid oracle setup");

        uint256 proposalId = governor.createProposal(nftContract, nftId, conditionId, targets, values, data, memo);

        proposalManager.markNFTUsed(nftId);

        (IUniswapV3Pool passPool, IUniswapV3Pool failPool,,,,) = oracle.conditions(conditionId);

        emit ProposalValidated(conditionId, address(passPool), address(failPool));

        return proposalId;
    }
}
