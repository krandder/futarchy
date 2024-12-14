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

## Development Status

This repository is under active development. Installation and development instructions will be added soon.
