/**
 * An IPFT tag is used to verify the authenticity of an IPFT.
 */
export class Tag {
  constructor(
    public readonly chainId: number,
    public readonly contractAddress: string,
    public readonly authorAddress: string
  ) {}

  toBytes(): Uint8Array {
    const tag = Buffer.alloc(56);

    tag.writeUint32BE(0x69706674); // "ipft"
    tag.writeUint32BE(0x0165766d, 4); // "\x{01}evm"
    tag.write(this.chainId.toString(16).padStart(16, "0"), 8, 8, "hex");
    tag.write(this.contractAddress.slice(2), 16, 20, "hex");
    tag.write(this.authorAddress.slice(2), 36, 20, "hex");

    return tag;
  }
}
