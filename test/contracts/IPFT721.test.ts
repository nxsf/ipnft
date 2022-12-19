// This test also covers "IPFT.sol".
//

import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import {
  LibIPFT__factory,
  IPFT721Impl__factory,
  IPFT721Impl,
} from "../../contracts/typechain";
import { contentBlock } from "./util";
import * as DagCbor from "@ipld/dag-cbor";
import { keccak256 } from "@multiformats/sha3";

use(solidity);

describe("IPFT721", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let chainId: number;
  let ipft721: IPFT721Impl;

  before(async () => {
    // FIXME: chainId = (await provider.getNetwork()).chainId;
    chainId = 1;

    const libIpft = await deployContract(w0, LibIPFT__factory as any);

    const ipft721Factory = new IPFT721Impl__factory(
      {
        "contracts/LibIPFT.sol:LibIPFT": libIpft.address,
      },
      w0
    );

    ipft721 = await ipft721Factory.deploy();
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
      const idHex = "0x" + Buffer.from(id).toString("hex");

      await expect(
        ipft721.mint(
          w0.address,
          id,
          block.bytes,
          block.cid.code,
          tagOffset,
          w0.address
        )
      )
        .to.emit(ipft721, "Claim")
        .withArgs(w0.address, DagCbor.code, keccak256.code, 32, idHex);

      expect(await ipft721.balanceOf(w0.address)).to.eq(1);
      expect(await ipft721.contentAuthorOf(id)).to.eq(w0.address);
      expect(await ipft721.ownerOf(id)).to.eq(w0.address);
      expect(await ipft721.contentCodecOf(id)).to.eq(DagCbor.code);
      expect(await ipft721.multihashCodecOf(id)).to.eq(keccak256.code);
      expect(await ipft721.multihashDigestSizeOf(id)).to.eq(32);
      expect(await ipft721.multihashDigestOf(id)).to.eq(idHex);
      expect(await ipft721.tokenURI(id)).to.eq(
        "http://f01711b20{id}.ipfs/metadata.json"
      );
    });
  });
});
