import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Get contract factories
  const GnosisCTFAdapter = await ethers.getContractFactory("GnosisCTFAdapter");

  // Deploy adapter
  const adapter = await GnosisCTFAdapter.deploy(
    process.env.GNOSIS_CTF_ADDRESS!, // Gnosis CTF address
    process.env.WRAPPED_1155_FACTORY! // Wrapped1155Factory address
  );
  await adapter.waitForDeployment();

  console.log("GnosisCTFAdapter deployed to:", adapter.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });