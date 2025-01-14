# Futarchy E2E Test with Ganache

## How to run

1. In one terminal, start Ganache:
   ```bash
   npm run start-ganache
   ```

2. In another terminal, run the test:
   ```bash
   npm run test-e2e
   ```

The script will:
- Deploy the Futarchy contracts to Ganache.
- Create a base pool with mock tokens.
- Split on a condition.
- Resolve the condition.
- Merge back into the base pool.

## Prerequisites

Make sure you have Node.js and npm installed. Then install dependencies:

```bash
cd test-e2e
npm install
``` 