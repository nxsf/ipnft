const { ethers } = require("hardhat");

async function deploy(contractName, deployOptions = {}, ...args) {
  const factory = await ethers.getContractFactory(contractName, deployOptions);
  const instance = await factory.deploy(...args);
  await instance.deployed();
  console.log(contractName, "deployed to", instance.address);
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
