# Futarchy Smart Contracts

This repository contains the core smart contracts for the Futarchy protocol, enabling market-based governance through conditional token markets.

## Core Components

### Pool Management
`FutarchyPoolManager`: Handles the creation, splitting, and merging of liquidity pools for conditional markets. Works with various pool protocols through adapters.

### Conditional Token Framework
`ICTFAdapter`: Interface for splitting and merging conditional tokens
`GnosisCTFAdapter`: Implementation for Gnosis Conditional Token Framework

### Oracle and Governance
`FAOOracle`: Provides market recommendations based on TWAP pricing
`FAOGovernor`: Executes governance actions based on oracle recommendations

### Proposal System
`DualAuctionManager`: Manages auctions for proposal rights
`ProposalManager`: Handles proposal creation and execution
