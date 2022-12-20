import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import {
  LibIPNFT__factory,
  IPNFT1155Impl__factory,
  IPNFT1155Impl,
} from "../../contracts/typechain";
import { contentBlock } from "./util";
import { BlockView } from "multiformats/block/interface";
import * as DagCbor from "@ipld/dag-cbor";
import { keccak256 } from "@multiformats/sha3";

use(solidity);

describe("IPNFT1155", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let chainId: number;
  let ipnft1155: IPNFT1155Impl;

  let block: BlockView;
  let id: Uint8Array;
  let idHex: string;
  let ipftOffset: number;

  before(async () => {
    // FIXME: chainId = (await provider.getNetwork()).chainId;
    chainId = 1;

    const libIpnft = await deployContract(w0, LibIPNFT__factory as any, []);

    const ipft1155Factory = new IPNFT1155Impl__factory(
      {
        "contracts/LibIPNFT.sol:LibIPNFT": libIpnft.address,
      },
      w0
    );

    ipnft1155 = await ipft1155Factory.deploy();

    const res = await contentBlock(chainId, ipnft1155.address, w0.address);

    block = res.block;
    id = block.cid.multihash.digest;
    idHex = "0x" + Buffer.from(id).toString("hex");
    ipftOffset = res.ipftOffset;
  });

  describe("claiming", () => {
    it("works", async () => {
      await expect(
        ipnft1155.claim(id, w0.address, block.bytes, block.cid.code, ipftOffset)
      )
        .to.emit(ipnft1155, "Claim")
        .withArgs(idHex, w0.address, DagCbor.code, keccak256.code);
    });
  });

  describe("minting", () => {
    describe("without prior claiming", () => {
      it("fails", async () => {
        await expect(ipnft1155.mint(w0.address, 42, 10, [])).to.be.revertedWith(
          "IPNFT1155: unauthorized"
        );
      });
    });

    describe("when claimed", () => {
      it("works", async () => {
        const w0BalanceBefore = await ipnft1155.balanceOf(w0.address, id);
        await ipnft1155.mint(w0.address, id, 10, []);
        expect(await ipnft1155.balanceOf(w0.address, id)).to.eq(
          w0BalanceBefore.add(10)
        );

        expect(await ipnft1155.contentIdOf(id)).to.eq(idHex);
        expect(await ipnft1155.contentAuthorOf(id)).to.eq(w0.address);
        expect(await ipnft1155.contentCodecOf(id)).to.eq(DagCbor.code);
        expect(await ipnft1155.multihashCodecOf(id)).to.eq(keccak256.code);
        expect(await ipnft1155.uri(id)).to.eq(
          "http://f01711b20{id}.ipfs/metadata.json"
        );
      });
    });

    describe("when not the owner", () => {
      it("fails", async () => {
        await expect(
          ipnft1155.connect(w1).mint(w1.address, id, 10, [])
        ).to.be.revertedWith("IPNFT1155: unauthorized");
      });
    });

    describe("when set approval for all", () => {
      before(async () => {
        await ipnft1155.setApprovalForAll(w1.address, true);
      });

      it("works", async () => {
        const w1BalanceBefore = await ipnft1155.balanceOf(w1.address, id);
        await ipnft1155.connect(w1).mint(w1.address, id, 10, []);
        expect(await ipnft1155.connect(w1).balanceOf(w1.address, id)).to.equal(
          w1BalanceBefore.add(10)
        );
      });
    });
  });
});
