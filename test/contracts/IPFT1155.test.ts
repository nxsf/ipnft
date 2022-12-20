import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import {
  LibIPFT__factory,
  IPFT1155Impl__factory,
  IPFT1155Impl,
} from "../../contracts/typechain";
import { contentBlock } from "./util";
import { BlockView } from "multiformats/block/interface";
import * as DagCbor from "@ipld/dag-cbor";
import { keccak256 } from "@multiformats/sha3";

use(solidity);

describe("IPFT1155", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let chainId: number;
  let ipft1155: IPFT1155Impl;

  let block: BlockView;
  let id: Uint8Array;
  let idHex: string;
  let tagOffset: number;

  before(async () => {
    // FIXME: chainId = (await provider.getNetwork()).chainId;
    chainId = 1;

    const libIpft = await deployContract(w0, LibIPFT__factory as any, []);

    const ipft1155Factory = new IPFT1155Impl__factory(
      {
        "contracts/LibIPFT.sol:LibIPFT": libIpft.address,
      },
      w0
    );

    ipft1155 = await ipft1155Factory.deploy();

    const res = await contentBlock(chainId, ipft1155.address, w0.address);

    block = res.block;
    id = block.cid.multihash.digest;
    idHex = "0x" + Buffer.from(id).toString("hex");
    tagOffset = res.tagOffset;
  });

  describe("claiming", () => {
    it("works", async () => {
      await expect(
        ipft1155.claim(id, w0.address, block.bytes, block.cid.code, tagOffset)
      )
        .to.emit(ipft1155, "Claim")
        .withArgs(idHex, w0.address, DagCbor.code, keccak256.code);
    });
  });

  describe("minting", () => {
    describe("without prior claiming", () => {
      it("fails", async () => {
        await expect(ipft1155.mint(w0.address, 42, 10, [])).to.be.revertedWith(
          "IPFT1155: unauthorized"
        );
      });
    });

    describe("when claimed", () => {
      it("works", async () => {
        const w0BalanceBefore = await ipft1155.balanceOf(w0.address, id);
        await ipft1155.mint(w0.address, id, 10, []);
        expect(await ipft1155.balanceOf(w0.address, id)).to.eq(
          w0BalanceBefore.add(10)
        );

        expect(await ipft1155.contentAuthorOf(id)).to.eq(w0.address);
        expect(await ipft1155.contentCodecOf(id)).to.eq(DagCbor.code);
        expect(await ipft1155.multihashCodecOf(id)).to.eq(keccak256.code);
        expect(await ipft1155.uri(id)).to.eq(
          "http://f01711b20{id}.ipfs/metadata.json"
        );
      });
    });

    describe("when not the owner", () => {
      it("fails", async () => {
        await expect(
          ipft1155.connect(w1).mint(w1.address, id, 10, [])
        ).to.be.revertedWith("IPFT1155: unauthorized");
      });
    });

    describe("when set approval for all", () => {
      before(async () => {
        await ipft1155.setApprovalForAll(w1.address, true);
      });

      it("works", async () => {
        const w1BalanceBefore = await ipft1155.balanceOf(w1.address, id);
        await ipft1155.connect(w1).mint(w1.address, id, 10, []);
        expect(await ipft1155.connect(w1).balanceOf(w1.address, id)).to.equal(
          w1BalanceBefore.add(10)
        );
      });
    });
  });
});
