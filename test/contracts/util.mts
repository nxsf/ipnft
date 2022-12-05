import { ethers } from "ethers";

export class IPFTTag {
  constructor(
    public readonly chainId: number,
    public readonly contract: string,
    public readonly author: string
  ) {}

  toBytes(): Uint8Array {
    const tag = Buffer.alloc(56);

    tag.writeUint32BE(0x69706674); // "ipft"
    tag.writeUint32BE(0x0165766d, 4); // "\x{01}evm"
    tag.write(this.chainId.toString(16).padStart(16, "0"), 8, 8, "hex");
    tag.write(this.contract.slice(2), 16, 20, "hex");
    tag.write(this.author.slice(2), 36, 20, "hex");

    return tag;
  }
}

export async function getChainId(
  provider: ethers.providers.Provider
): Promise<number> {
  // FIXME: It is 1337 locally, but 1 in the contract.
  // return (await provider.getNetwork()).chainId;
  return 1;
}
