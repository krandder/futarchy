import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { MockERC20, MockConditionalTokens, MockWrapped1155Factory, GnosisCTFAdapter } from "../../typechain-types";

describe("GnosisCTFAdapter", function () {
    let adapter: GnosisCTFAdapter;
    let conditionalTokens: MockConditionalTokens;
    let wrapped1155Factory: MockWrapped1155Factory;
    let owner: Signer;
    let user: Signer;
    let collateralToken: MockERC20;

    beforeEach(async function () {
        [owner, user] = await ethers.getSigners();

        // Deploy mock contracts
        const MockERC20Factory = await ethers.getContractFactory("MockERC20");
        collateralToken = await MockERC20Factory.deploy("Test Token", "TEST") as MockERC20;
        await collateralToken.waitForDeployment();

        const MockCTFactory = await ethers.getContractFactory("MockConditionalTokens");
        conditionalTokens = await MockCTFactory.deploy() as MockConditionalTokens;
        await conditionalTokens.waitForDeployment();

        const MockWrapperFactory = await ethers.getContractFactory("MockWrapped1155Factory");
        wrapped1155Factory = await MockWrapperFactory.deploy() as MockWrapped1155Factory;
        await wrapped1155Factory.waitForDeployment();

        // Deploy adapter
        const AdapterFactory = await ethers.getContractFactory("GnosisCTFAdapter");
        adapter = await AdapterFactory.deploy(
            await conditionalTokens.getAddress(),
            await wrapped1155Factory.getAddress()
        ) as GnosisCTFAdapter;
        await adapter.waitForDeployment();

        // Mint tokens to user
        await collateralToken.mint(await user.getAddress(), ethers.parseEther("1000"));
        await collateralToken.connect(user).approve(await adapter.getAddress(), ethers.parseEther("1000"));
    });

    describe("splitCollateralTokens", function () {
        it("should split tokens correctly for binary outcome", async function () {
            const amount = ethers.parseEther("100");
            const oracle = await owner.getAddress();
            const questionId = ethers.keccak256(ethers.toUtf8Bytes("Did it rain today?"));
            const conditionId = await conditionalTokens.getConditionId(oracle, questionId, 2);
            
            await conditionalTokens.prepareCondition(oracle, questionId, 2);
            
            const tx = await adapter.connect(user).splitCollateralTokens(
                await collateralToken.getAddress(),
                conditionId,
                amount,
                2
            );
            await tx.wait();

            const conditionalTokensAddress = await conditionalTokens.getAddress();
            expect(await collateralToken.balanceOf(conditionalTokensAddress)).to.equal(amount);
        });
    });
});