// This test also covers "IPNFT.sol".
//

import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import {
  LibIPNFT__factory,
  IPNFT721Impl__factory,
  IPNFT721Impl,
} from "../../contracts/typechain";
import { contentBlock } from "./util";
import * as DagCbor from "@ipld/dag-cbor";
import { keccak256 } from "@multiformats/sha3";

use(solidity);

describe("IPNFT721", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let chainId: number;
  let ipnft721: IPNFT721Impl;

  before(async () => {
    // FIXME: chainId = (await provider.getNetwork()).chainId;
    chainId = 1;

    const libIpnft = await deployContract(w0, LibIPNFT__factory as any);

    const ipnft721Factory = new IPNFT721Impl__factory(
      {
        "contracts/LibIPNFT.sol:LibIPNFT": libIpnft.address,
      },
      w0
    );

    ipnft721 = await ipnft721Factory.deploy();
  });

  describe("minting", () => {
    it("fails on invalid IPFT offset", async () => {
      const { block, ipftOffset } = await contentBlock(
        chainId,
        ipnft721.address,
        w0.address
      );

      await expect(
        ipnft721.mint(
          w0.address,
          block.cid.multihash.digest,
          w0.address,
          block.bytes,
          block.cid.code,
          ipftOffset + 1 // This
        )
      ).to.be.revertedWith("IPNFT: invalid magic bytes");
    });

    it("works", async () => {
      const { block, ipftOffset: tagOffset } = await contentBlock(
        chainId,
        ipnft721.address,
        w0.address
      );

      const id = block.cid.multihash.digest;
      const idHex = "0x" + Buffer.from(id).toString("hex");

      await expect(
        ipnft721.mint(
          w0.address,
          id,
          w0.address,
          block.bytes,
          block.cid.code,
          tagOffset
        )
      )
        .to.emit(ipnft721, "Claim")
        .withArgs(idHex, w0.address, DagCbor.code, keccak256.code);

      expect(await ipnft721.balanceOf(w0.address)).to.eq(1);
      expect(await ipnft721.contentIdOf(id)).to.eq(idHex);
      expect(await ipnft721.contentAuthorOf(id)).to.eq(w0.address);
      expect(await ipnft721.ownerOf(id)).to.eq(w0.address);
      expect(await ipnft721.contentCodecOf(id)).to.eq(DagCbor.code);
      expect(await ipnft721.multihashCodecOf(id)).to.eq(keccak256.code);
      expect(await ipnft721.tokenURI(id)).to.eq(
        "http://f01711b20{id}.ipfs/metadata.json"
      );
    });
  });
});
