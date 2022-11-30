import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import Ipft721ABI from "../../waffle/IPFT721.json";
import { Ipft721 } from "../../waffle/types/Ipft721";
import Ipft1155ABI from "../../waffle/IPFT1155.json";
import { Ipft1155 } from "../../waffle/types/Ipft1155";
import * as DagCbor from "@ipld/dag-cbor";
import { ByteView, CID, digest } from "multiformats";
import { keccak256 } from "@multiformats/sha3";
import { ipftTag, getChainId } from "./util.mjs";

use(solidity);

describe("IPFT(1155)", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let ipft721: Ipft721;
  let ipft1155: Ipft1155;

  let content: ByteView<any>, multihash: digest.Digest<27, number>;

  before(async () => {
    ipft721 = (await deployContract(w0, Ipft721ABI)) as Ipft721;

    ipft1155 = (await deployContract(w0, Ipft1155ABI, [
      ipft721.address,
    ])) as Ipft1155;

    content = DagCbor.encode({
      metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
      ipft: ipftTag(await getChainId(provider), ipft721.address, w0.address, 0),
    });

    multihash = await keccak256.digest(content);
  });

  describe("minting", () => {
    describe("when IPFT(721) doesn't exist", () => {
      it("fails", async () => {
        await expect(
          ipft1155.mint(w0.address, multihash.digest, 10, false, [])
        ).to.be.revertedWith("ERC721: invalid token ID");
      });

      after(async () => {
        await ipft721.mint(
          w0.address,
          multihash.digest,
          content,
          8,
          DagCbor.code,
          10
        );
      });
    });

    describe("when IPFT(721) is owned", () => {
      it("works", async () => {
        const w0BalanceBefore = await ipft1155.balanceOf(
          w0.address,
          multihash.digest
        );

        const totalSupplyBefore = await ipft1155.totalSupply(multihash.digest);

        await ipft1155.mint(w0.address, multihash.digest, 10, false, []);

        expect(await ipft1155.balanceOf(w0.address, multihash.digest)).to.eq(
          w0BalanceBefore.add(10)
        );

        expect(await ipft1155.totalSupply(multihash.digest)).to.equal(
          totalSupplyBefore.add(10)
        );
      });
    });

    describe("when IPFT(721) is not possesed", () => {
      it("fails", async () => {
        await expect(
          ipft1155.connect(w1).mint(w1.address, multihash.digest, 10, false, [])
        ).to.be.revertedWith("IPFT(1155): IPFT(721)-unauthorized");
      });
    });

    describe("when IPFT(721) is authorized", () => {
      before(async () => {
        await ipft721.setApprovalForAll(w1.address, true);
      });

      it("works", async () => {
        const w1BalanceBefore = await ipft1155.balanceOf(
          w1.address,
          multihash.digest
        );

        await ipft1155
          .connect(w1)
          .mint(w1.address, multihash.digest, 10, false, []);

        expect(
          await ipft1155.connect(w1).balanceOf(w1.address, multihash.digest)
        ).to.equal(w1BalanceBefore.add(10));
      });
    });

    describe("when finalized", () => {
      before(async () => {
        await ipft1155.mint(w0.address, multihash.digest, 0, true, []);
      });

      it("fails", async () => {
        expect(await ipft1155.isFinalized(multihash.digest)).to.be.true;

        await expect(
          ipft1155.mint(w0.address, multihash.digest, 10, false, [])
        ).to.be.revertedWith("IPFT(1155): finalized");
      });
    });
  });
});
