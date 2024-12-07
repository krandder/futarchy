import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";

describe("GnosisCTFAdapter", function () {
  let adapter: Contract;
  let conditionalTokens: Contract;
  let wrapped1155Factory: Contract;
  let owner: Signer;
  let user: Signer;
  let collateralToken: Contract;
  
  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    // Deploy mock contracts
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    collateralToken = await MockERC20.deploy("Test Token", "TEST");

    const MockConditionalTokens = await ethers.getContractFactory("MockConditionalTokens");
    conditionalTokens = await MockConditionalTokens.deploy();

    const MockWrapped1155Factory = await ethers.getContractFactory("MockWrapped1155Factory");
    wrapped1155Factory = await MockWrapped1155Factory.deploy();

    const GnosisCTFAdapter = await ethers.getContractFactory("GnosisCTFAdapter");
    adapter = await GnosisCTFAdapter.deploy(
      conditionalTokens.address,
      wrapped1155Factory.address
    );

    // Mint some tokens to user
    await collateralToken.mint(await user.getAddress(), ethers.parseEther("1000"));
    await collateralToken.connect(user).approve(adapter.address, ethers.parseEther("1000"));
  });

  describe("splitCollateralTokens", function () {
    const questionId = ethers.keccak256(ethers.toUtf8Bytes("Did it rain today?"));
    
    it("should split tokens correctly for binary outcome", async function () {
      const amount = ethers.parseEther("100");
      const oracle = await owner.getAddress();
      const conditionId = await conditionalTokens.getConditionId(oracle, questionId, 2);
      
      await conditionalTokens.prepareCondition(oracle, questionId, 2);
      
      const wrappedTokens = await adapter.connect(user).splitCollateralTokens(
        collateralToken.address,
        conditionId,
        amount,
        2
      );

      expect(wrappedTokens.length).to.equal(2);
      expect(await collateralToken.balanceOf(conditionalTokens.address)).to.equal(amount);
    });

    it("should revert with invalid outcome count", async function () {
      const amount = ethers.parseEther("100");
      const oracle = await owner.getAddress();
      const conditionId = await conditionalTokens.getConditionId(oracle, questionId, 1);

      await expect(
        adapter.connect(user).splitCollateralTokens(
          collateralToken.address,
          conditionId,
          amount,
          1
        )
      ).to.be.revertedWithCustomError(adapter, "InvalidOutcomeCount");
    });
  });

  describe("redeemPositions", function () {
    const questionId = ethers.keccak256(ethers.toUtf8Bytes("Did it rain today?"));
    
    it("should redeem positions correctly after resolution", async function () {
      const amount = ethers.parseEther("100");
      const oracle = await owner.getAddress();
      const conditionId = await conditionalTokens.getConditionId(oracle, questionId, 2);
      
      await conditionalTokens.prepareCondition(oracle, questionId, 2);
      
      // Split tokens
      await adapter.connect(user).splitCollateralTokens(
        collateralToken.address,
        conditionId,
        amount,
        2
      );

      // Simulate condition resolution
      await conditionalTokens.setPayoutDenominator(conditionId, 2);

      // Redeem positions
      const beforeBalance = await collateralToken.balanceOf(await user.getAddress());
      await adapter.connect(user).redeemPositions(
        collateralToken.address,
        conditionId,
        [amount, amount],
        2
      );
      const afterBalance = await collateralToken.balanceOf(await user.getAddress());

      expect(afterBalance - beforeBalance).to.equal(amount);
    });

    it("should revert when condition not resolved", async function () {
      const amount = ethers.parseEther("100");
      const oracle = await owner.getAddress();
      const conditionId = await conditionalTokens.getConditionId(oracle, questionId, 2);

      await expect(
        adapter.connect(user).redeemPositions(
          collateralToken.address,
          conditionId,
          [amount, amount],
          2
        )
      ).to.be.revertedWithCustomError(adapter, "ConditionNotResolved");
    });
  });
});