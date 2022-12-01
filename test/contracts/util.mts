import { ethers } from "ethers";

export class IPFTTag {
  constructor(
    public readonly chainId: number,
    public readonly contract: string,
    public readonly author: string,
    public readonly nonce: number
  ) {}

  toBytes(): Uint8Array {
    const tag = Buffer.alloc(84);

    tag.writeUint32BE(0x69706674); // "ipft"
    tag.writeUint8(0x01, 4); // version
    tag.writeUint32BE(0x65766d00, 5); // "evm\0"
    tag.write(this.chainId.toString(16).padStart(64, "0"), 8, 32, "hex");
    tag.write(this.contract.slice(2), 40, 20, "hex");
    tag.write(this.author.slice(2), 60, 20, "hex");
    tag.writeUInt32BE(this.nonce, 80);

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
