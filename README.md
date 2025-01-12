# Futarchy Protocol Smart Contracts

This repository contains the core smart contracts for the Futarchy protocol, enabling market-based governance through conditional token markets. The protocol is currently under active development.

## Directory Structure

### Core Components
- `src/FutarchyPoolManager.sol`: Manages conditional pools for market creation
- `src/pools/BalancerPoolWrapper.sol`: Balancer pool integration

### Conditional Token Framework
- `src/interfaces/ICTFAdapter.sol`: Interface for conditional token operations
- `src/gnosis/GnosisCTFAdapter.sol`: Implementation for Gnosis CTF

### Optimizer Module
- `src/optimizer/FaoGovernor.sol`: Governance execution contract
- `src/optimizer/FaoOracleSafe.sol`: Oracle for market evaluations
- `src/optimizer/ProposalManager.sol`: Handles proposal lifecycle
- `src/optimizer/DualAuctionManager.sol`: Manages proposal right auctions
- `src/optimizer/FAOToken.sol`: Protocol token implementation
- `src/optimizer/FAOIco.sol`: Token distribution contract

### Combinatorial Framework
- `src/combinatorial/`: Advanced combinatorial market framework (WIP)

## Deployed Contracts (Gnosis Chain)

All contracts are deployed and verified on Gnosis Chain:

1. **GnosisCTFAdapter**  
   - **Address:** [0xf7D40E56Ce7bC655f25158b858bd2F389be7cd58](https://gnosisscan.io/address/0xf7d40e56ce7bc655f25158b858bd2f389be7cd58)

2. **BalancerPoolWrapper**  
   - **Address:** [0xfd555C89479ED956943a5765ebcD095BDF89e9cD](https://gnosisscan.io/address/0xfd555c89479ed956943a5765ebcd095bdf89e9cd)

3. **FutarchyPoolManager**  
   - **Address:** [0x2F87A34d6302d1edB8a49Fd0eF4C8707E3Da4F7a](https://gnosisscan.io/address/0x2f87a34d6302d1edb8a49fd0ef4c8707e3da4f7a)

4. **ProposalNFT**  
   - **Address:** [0x58D829124D63F1Eb4C0795F82becDb31912c5F46](https://gnosisscan.io/address/0x58d829124d63f1eb4c0795f82becdb31912c5f46)

5. **FutarchyRandomFailure**  
   - **Address:** [0x32337445f0B9c23604cb6903e288ADD3F6E9d0Bc](https://gnosisscan.io/address/0x32337445f0b9c23604cb6903e288add3f6e9d0bc)

6. **FutarchyOracle**  
   - **Address:** [0x3384fC4eF4e8e71D1019bD284B8F696898cb7549](https://gnosisscan.io/address/0x3384fc4ef4e8e71d1019bd284b8f696898cb7549)

7. **FutarchyGovernor**  
   - **Address:** [0x5AFf67B1402972217B592E719B19553528ffF879](https://gnosisscan.io/address/0x5aff67b1402972217b592e719b19553528fff879)

8. **ProposalManager**  
   - **Address:** [0x1a037ACbD3fb1c72081c57390960a02b3A87B099](https://gnosisscan.io/address/0x1a037acbd3fb1c72081c57390960a02b3a87b099)

9. **FutarchyProposerGuard**  
   - **Address:** [0x261F6c7c3e5AF800f03A4A165496ED3d237fAEee](https://gnosisscan.io/address/0x261f6c7c3e5af800f03a4a165496ed3d237faeee)

10. **ProposalManager** (final instance)  
    - **Address:** [0x60832eaA8082aB8577Eae7a1f076cb7400DdA750](https://gnosisscan.io/address/0x60832eaa8082ab8577eae7a1f076cb7400dda750)

All contracts are verified and can be interacted with through GnosisScan.

## Development Status

This repository is under active development. Installation and development instructions will be added soon.
