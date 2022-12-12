const { ethers } = require("hardhat");

async function deploy(contractName, deployOptions = {}, ...args) {
  const factory = await ethers.getContractFactory(contractName, deployOptions);

  const balance = await factory.signer.getBalance();
  console.log(`Balance: ${ethers.utils.formatEther(balance)}`);

  const deployTx = factory.getDeployTransaction(...args);

  const estimatedGas = await factory.signer.estimateGas(deployTx);
  const gasPrice = await factory.signer.getGasPrice();

  const deploymentPriceWei = gasPrice.mul(estimatedGas);
  console.log(`Estimated gas for ${contractName}: ${estimatedGas}`);
  console.log(
    `Estimated gas price for ${contractName}: ${ethers.utils.formatEther(
      deploymentPriceWei
    )}`
  );

  const instance = await factory.deploy(...args);
  await instance.deployed();
  console.log(contractName, "deployed to", instance.address);
  console.log("Transaction hash:", instance.deployTransaction.hash);

  return instance;
}

async function main() {
  const ipft = await deploy("IPFT");
  await deploy("IPFT721", { libraries: { IPFT: ipft.address } });
  await deploy("IPFT1155", { libraries: { IPFT: ipft.address } });
  await deploy("IPFTRedeemable", { libraries: { IPFT: ipft.address } });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
