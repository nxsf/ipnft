// This test also covers "IPFT.sol".
//

import { expect, use } from "chai";
import { deployContract, MockProvider, solidity, link } from "ethereum-waffle";
import IpftABI from "../../contracts/IPFT.json" assert { type: "json" };
import Ipft721ImplABI from "../../contracts/IPFT721Impl.json" assert { type: "json" };
import { Ipft721Impl } from "../../contracts/types/Ipft721Impl.js";
import { contentBlock } from "./util.mjs";
import * as DagCbor from "@ipld/dag-cbor";

use(solidity);

describe("IPFT721", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let chainId: number;
  let ipft721: Ipft721Impl;

  before(async () => {
    // FIXME: chainId = (await provider.getNetwork()).chainId;
    chainId = 1;

    const ipft = await deployContract(w0, IpftABI);
    link(Ipft721ImplABI, "contracts/IPFT.sol:IPFT", ipft.address);
    ipft721 = (await deployContract(w0, Ipft721ImplABI)) as Ipft721Impl;
  });

  describe("minting", () => {
    it("fails on invalid tag offset", async () => {
      const { block, tagOffset } = await contentBlock(
        chainId,
        ipft721.address,
        w0.address
      );

      await expect(
        ipft721.mint(
          w0.address,
          block.cid.multihash.digest,
          block.bytes,
          block.cid.code,
          tagOffset + 1, // This
          w0.address
        )
      ).to.be.revertedWith("IPFT: invalid magic bytes");
    });

    it("works", async () => {
      const { block, tagOffset } = await contentBlock(
        chainId,
        ipft721.address,
        w0.address
      );

      const id = block.cid.multihash.digest;

      await ipft721.mint(
        w0.address,
        id,
        block.bytes,
        block.cid.code,
        tagOffset,
        w0.address
      );

      expect(await ipft721.balanceOf(w0.address)).to.eq(1);
      expect(await ipft721.authorOf(id)).to.eq(w0.address);
      expect(await ipft721.ownerOf(id)).to.eq(w0.address);
      expect(await ipft721.codecOf(id)).to.eq(DagCbor.code);
      expect(await ipft721.tokenURI(id)).to.eq(
        "http://f01711b20{id}.ipfs/metadata.json"
      );
    });
  });
});
