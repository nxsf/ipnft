const { ethers } = require("hardhat");

async function deploy(contractName, ...args) {
  const factory = await ethers.getContractFactory(contractName);
  const instance = await factory.deploy(...args);
  await instance.deployed();
  console.log(contractName, "deployed to", instance.address);
  return instance;
}

async function main() {
  const ipnft721 = await deploy("IPNFT721");
  await deploy("IPNFT1155", ipnft721.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
