# Futarchy

Smart contracts implementing futarchy and combinatorial prediction markets on EVM chains. Includes interfaces for existing conditional token frameworks (like Gnosis CTF) and a new implementation based on Robin Hanson's combinatorial information markets.

## Overview

This project provides smart contract infrastructure for futarchy mechanisms:

1. Gnosis CTF Adapter
   - Clean ERC20-only interface for conditional tokens
   - Simplified splitting and merging operations
   - Automatic token wrapping for AMM compatibility

2. Futarchy CTF (Coming Soon)
   - Implementation of combinatorial prediction markets
   - Based on Robin Hanson's research
   - Support for complex conditional expressions

## Quick Start

### Installation
```bash
git clone https://github.com/tickspread/futarchy.git
cd futarchy
npm install
```

### Testing
```bash
npx hardhat test
```

## Architecture

### GnosisCTFAdapter
Provides a simplified interface for interacting with Gnosis Conditional Token Framework:
- Split ERC20 tokens into outcome-specific tokens
- Automatic wrapping into tradeable ERC20 tokens
- Handle redemptions after condition resolution

Example usage:
```solidity
// Split tokens into YES/NO positions
address[] wrappedTokens = adapter.splitCollateralTokens(
    collateralToken,
    conditionId,
    amount,
    2  // binary outcome
);

// Later redeem positions after condition resolves
uint256 payout = adapter.redeemPositions(
    collateralToken,
    conditionId,
    amounts,
    2
);
```

### Futarchy CTF (In Development)
A new implementation supporting:
- Complex conditional expressions
- Multiple outcome spaces
- Efficient settlement mechanisms

## Development

### Prerequisites
- Node.js >= 16
- npm or yarn
- Hardhat

### Local Setup
```bash
# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test
```

### Project Structure
```
contracts/
├── adapters/         # Interfaces to existing frameworks
│   └── gnosis/      # Gnosis CTF adapter
├── ctf/             # Combinatorial Token Framework
│   ├── core/        # Core CTF contracts
│   └── interfaces/  # CTF interfaces
└── shared/          # Shared utilities and interfaces

test/
├── adapters/        # Tests for adapters
└── ctf/            # Tests for CTF implementation
```

## Documentation

- [Architecture Overview](docs/architecture/README.md)
- [Gnosis CTF Adapter](docs/gnosis-adapter/README.md)
- [Futarchy CTF](docs/futarchy-ctf/README.md)

## Security

This project is in active development and has not been audited yet. Use at your own risk.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see the [LICENSE](LICENSE) file for details
