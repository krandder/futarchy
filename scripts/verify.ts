import { run } from "hardhat";

async function main() {
  const ADAPTER_ADDRESS = ""; // Fill in after deployment
  const GNOSIS_CTF_ADDRESS = process.env.GNOSIS_CTF_ADDRESS!;
  const WRAPPED_1155_FACTORY = process.env.WRAPPED_1155_FACTORY!;

  console.log("Verifying GnosisCTFAdapter...");
  
  try {
    await run("verify:verify", {
      address: ADAPTER_ADDRESS,
      constructorArguments: [
        GNOSIS_CTF_ADDRESS,
        WRAPPED_1155_FACTORY
      ],
    });
  } catch (e) {
    console.log(e);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });