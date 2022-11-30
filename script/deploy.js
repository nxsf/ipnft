const { ethers } = require("hardhat");

async function deploy(contractName, ...args) {
  const factory = await ethers.getContractFactory(contractName);
  const instance = await factory.deploy(...args);
  await instance.deployed();
  console.log(contractName, "deployed to", instance.address);
  return instance;
}

async function main() {
  const ipft721 = await deploy("IPFT721");
  await deploy("IPFT1155", ipft721.address);
  await deploy("IPFT1155Redeemable", ipft721.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
