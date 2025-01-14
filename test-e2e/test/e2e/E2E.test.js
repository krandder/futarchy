const { strict: assert } = require('assert');
const Web3 = require('web3');
const fs = require('fs');
const path = require('path');

describe('Futarchy E2E Test (Ganache)', function () {
  let web3;
  let accounts;

  // Load contract artifacts
  const MockERC20Artifact = JSON.parse(
    fs.readFileSync(path.join(__dirname, '../../out/MockERC20.sol/MockERC20.json'), 'utf8')
  );

  const MockConditionalTokensArtifact = JSON.parse(
    fs.readFileSync(path.join(__dirname, '../../out/MockConditionalTokens.sol/MockConditionalTokens.json'), 'utf8')
  );

  // Fix bytecode format
  MockERC20Artifact.bytecode = MockERC20Artifact.bytecode.object;
  MockConditionalTokensArtifact.bytecode = MockConditionalTokensArtifact.bytecode.object;

  // Deployed contract instances
  let mockERC20Outcome;
  let mockERC20Money;
  let mockConditionalTokens;
  let gnosisCTFAdapter;
  let balancerWrapper;
  let futarchyManager;

  // Sample addresses
  let deployer;
  let user;

  before(async function () {
    // Connect to Ganache
    web3 = new Web3("http://127.0.0.1:8545");
    accounts = await web3.eth.getAccounts();
    deployer = accounts[0];
    user = accounts[1];
  });

  it("should deploy all contracts successfully", async function () {
    // Deploy MockERC20 as "Outcome" token
    {
      const contract = new web3.eth.Contract(MockERC20Artifact.abi);
      mockERC20Outcome = await contract
        .deploy({ data: MockERC20Artifact.bytecode, arguments: ["Outcome Token", "OUT"] })
        .send({ from: deployer, gas: 6_000_000 });
      assert.ok(mockERC20Outcome.options.address);
    }

    // Deploy second MockERC20 as "Money" token
    {
      const contract = new web3.eth.Contract(MockERC20Artifact.abi);
      mockERC20Money = await contract
        .deploy({ data: MockERC20Artifact.bytecode, arguments: ["Money Token", "MON"] })
        .send({ from: deployer, gas: 6_000_000 });
      assert.ok(mockERC20Money.options.address);
    }

    // Deploy MockConditionalTokens
    {
      const contract = new web3.eth.Contract(MockConditionalTokensArtifact.abi);
      mockConditionalTokens = await contract
        .deploy({ data: MockConditionalTokensArtifact.bytecode })
        .send({ from: deployer, gas: 6_000_000 });
      assert.ok(mockConditionalTokens.options.address);
    }

    console.log("Deployed contracts:");
    console.log("- MockERC20 Outcome:", mockERC20Outcome.options.address);
    console.log("- MockERC20 Money:", mockERC20Money.options.address);
    console.log("- MockConditionalTokens:", mockConditionalTokens.options.address);
  });

  it("should mint tokens to user and approve spending", async function () {
    const mintAmount = web3.utils.toWei("1000", "ether");

    await mockERC20Outcome.methods
      .mint(user, mintAmount)
      .send({ from: deployer, gas: 500_000 });

    await mockERC20Money.methods
      .mint(user, mintAmount)
      .send({ from: deployer, gas: 500_000 });

    // For now, we'll skip the approval since we don't have FutarchyPoolManager yet
    console.log("Minted tokens for user:", user);
    
    // Verify balances
    const outcomeBalance = await mockERC20Outcome.methods.balanceOf(user).call();
    const moneyBalance = await mockERC20Money.methods.balanceOf(user).call();
    
    assert.equal(outcomeBalance, mintAmount, "Incorrect OUT balance");
    assert.equal(moneyBalance, mintAmount, "Incorrect MON balance");
  });

  it("should create condition and resolve it", async function () {
    const conditionId = web3.utils.soliditySha3("Test Condition #1");

    await mockConditionalTokens.methods
      .prepareCondition(deployer, conditionId, 2)
      .send({ from: deployer, gas: 300_000 });

    console.log("Created condition with ID:", conditionId);

    // Verify condition was created
    const condition = await mockConditionalTokens.methods.conditions(conditionId).call();
    assert.equal(condition.oracle, deployer, "Incorrect oracle");
    assert.equal(condition.outcomeSlotCount, "2", "Incorrect outcome slot count");
    assert.equal(condition.isResolved, false, "Should not be resolved yet");

    // Simulate resolution (YES outcome)
    await mockConditionalTokens.methods
      .setPayoutDenominator(conditionId, 2)
      .send({ from: deployer, gas: 100_000 });

    // Verify resolution
    const resolvedCondition = await mockConditionalTokens.methods.conditions(conditionId).call();
    assert.equal(resolvedCondition.isResolved, true, "Should be resolved");
    assert.equal(resolvedCondition.payoutDenominator, "2", "Incorrect payout denominator");

    console.log("Resolved condition as YES");
  });
}); 