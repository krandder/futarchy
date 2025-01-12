// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

// Core Futarchy
import { FutarchyPoolManager } from "../src/FutarchyPoolManager.sol";
import { GnosisCTFAdapter } from "../src/gnosis/GnosisCTFAdapter.sol";
import { BalancerPoolWrapper } from "../src/pools/BalancerPoolWrapper.sol";
import { FutarchyProposerGuard } from "../src/FAO/FutarchyProposerGuard.sol";
import { FutarchyGovernor } from "../src/FAO/FutarchyGovernor.sol";
import { FutarchyOracle } from "../src/FAO/FutarchyOracle.sol";
import { FutarchyRandomFailure } from "../src/FAO/FutarchyRandomFailure.sol";
import { ProposalNFT } from "../src/FAO/ProposalNFT.sol";
import { ProposalManager } from "../src/FAO/ProposalManager.sol";

// Gnosis Conditional Tokens
import { IConditionalTokens } from "../src/interfaces/IConditionalTokens.sol";
import { IWrapped1155Factory } from "../src/interfaces/IWrapped1155Factory.sol";

contract DeployFutarchy is Script {
    // Deployed contract addresses (for reference after script run)
    GnosisCTFAdapter public gnosisCTFAdapter;
    BalancerPoolWrapper public balancerPoolWrapper;
    FutarchyPoolManager public futarchyPoolManager;
    ProposalNFT public proposalNFT;
    ProposalManager public proposalManager;
    FutarchyRandomFailure public futarchyRandomFailure;
    FutarchyOracle public futarchyOracle;
    FutarchyGovernor public futarchyGovernor;
    FutarchyProposerGuard public futarchyProposerGuard;

    // External addresses (to be set in the constructor or read from environment)
    address public constant CONDITIONAL_TOKENS = 0xCeAfDD6bc0bEF976fdCd1112955828E00543c0Ce; // Gnosis Chain
    address public constant WRAPPED_1155_FACTORY = 0x191Ccf8B088120082b127002e59d701b684C338c; // Gnosis Chain
    address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8; // Gnosis Chain
    address public constant CHAINLINK_VRF_COORDINATOR = address(0); // Replace with actual VRF coordinator

    // Configuration parameters
    uint64 public constant VRF_SUBSCRIPTION_ID = 1;
    bytes32 public constant VRF_KEY_HASH = 0x0000000000000000000000000000000000000000000000000000000000000000; // Replace with actual key hash
    uint256 public constant MIN_ORACLE_LIQUIDITY = 1e18;

    function run() external {
        // Get deployer address from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy GnosisCTFAdapter
        gnosisCTFAdapter = new GnosisCTFAdapter(CONDITIONAL_TOKENS, WRAPPED_1155_FACTORY);

        // 2. Deploy BalancerPoolWrapper
        balancerPoolWrapper = new BalancerPoolWrapper(BALANCER_VAULT);

        // 3. Deploy FutarchyPoolManager
        futarchyPoolManager = new FutarchyPoolManager(
            address(gnosisCTFAdapter),
            address(balancerPoolWrapper),
            address(0), // outcomeToken - to be set by admin
            address(0), // moneyToken - to be set by admin
            true, // useEnhancedSecurity
            deployer // admin
        );

        // 4. Deploy ProposalNFT
        proposalNFT = new ProposalNFT(deployer);

        // 5. Deploy FutarchyRandomFailure
        futarchyRandomFailure = new FutarchyRandomFailure(CHAINLINK_VRF_COORDINATOR, VRF_SUBSCRIPTION_ID, VRF_KEY_HASH);

        // 6. Deploy FutarchyOracle
        futarchyOracle = new FutarchyOracle(address(futarchyRandomFailure), CONDITIONAL_TOKENS);

        // 7. Deploy FutarchyGovernor (without ProposerGuard initially)
        futarchyGovernor = new FutarchyGovernor(
            CONDITIONAL_TOKENS,
            address(0) // proposerGuard - will be set in constructor
        );

        // 8. Deploy ProposalManager (with temporary ProposerGuard)
        // Note: We'll deploy a new one after setting up the real ProposerGuard
        ProposalManager tempProposalManager = new ProposalManager(
            address(proposalNFT),
            deployer // temporary proposerGuard
        );

        // 9. Deploy FutarchyProposerGuard (with all addresses)
        futarchyProposerGuard = new FutarchyProposerGuard(
            CONDITIONAL_TOKENS,
            WRAPPED_1155_FACTORY,
            payable(address(futarchyGovernor)),
            MIN_ORACLE_LIQUIDITY,
            deployer,
            payable(address(tempProposalManager))
        );

        // 10. Deploy final ProposalManager (with real ProposerGuard)
        proposalManager = new ProposalManager(address(proposalNFT), address(futarchyProposerGuard));

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("Deployed Addresses:");
        console.log("------------------");
        console.log("GnosisCTFAdapter:", address(gnosisCTFAdapter));
        console.log("BalancerPoolWrapper:", address(balancerPoolWrapper));
        console.log("FutarchyPoolManager:", address(futarchyPoolManager));
        console.log("ProposalNFT:", address(proposalNFT));
        console.log("FutarchyRandomFailure:", address(futarchyRandomFailure));
        console.log("FutarchyOracle:", address(futarchyOracle));
        console.log("FutarchyGovernor:", address(futarchyGovernor));
        console.log("ProposalManager:", address(proposalManager));
        console.log("FutarchyProposerGuard:", address(futarchyProposerGuard));
    }
}
