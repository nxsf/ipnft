import { ethers } from "ethers";

export function ipftTag(
  chainId: number,
  contractAddress: string,
  minterAddress: string,
  minterNonce: number
) {
  const tag = Buffer.alloc(80);

  tag.writeUint32BE(0x65766d01);
  tag.write(chainId.toString(16).padStart(64, "0"), 4, 32, "hex");
  tag.write(contractAddress.slice(2), 36, 20, "hex");
  tag.write(minterAddress.slice(2), 56, 20, "hex");
  tag.writeUInt32BE(minterNonce, 76);

  return tag;
}

export async function getChainId(
  provider: ethers.providers.Provider
): Promise<number> {
  // FIXME: It is 1337 locally, but 1 in the contract.
  // return (await provider.getNetwork()).chainId;
  return 1;
}
