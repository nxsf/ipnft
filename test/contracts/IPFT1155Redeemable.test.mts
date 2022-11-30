import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import Ipft721ABI from "../../waffle/IPFT721.json";
import { Ipft721 } from "../../waffle/types/Ipft721";
import Ipft1155RedeemableABI from "../../waffle/IPFT1155Redeemable.json";
import { Ipft1155Redeemable } from "../../waffle/types/Ipft1155Redeemable";
import * as DagCbor from "@ipld/dag-cbor";
import { ByteView, CID, digest } from "multiformats";
import { keccak256 } from "@multiformats/sha3";
import { ipftTag, getChainId } from "./util.mjs";
import { addMonths } from "date-fns";
import { BigNumber } from "ethers";

use(solidity);

describe("IPFT(1155)Redeemable", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let ipft721: Ipft721;
  let ipft1155Redeemable: Ipft1155Redeemable;

  let content: ByteView<any>, multihash: digest.Digest<27, number>;
  let expiresAt = Math.round(addMonths(new Date(), 1).valueOf() / 1000);

  before(async () => {
    ipft721 = (await deployContract(w0, Ipft721ABI)) as Ipft721;

    ipft1155Redeemable = (await deployContract(w0, Ipft1155RedeemableABI, [
      ipft721.address,
    ])) as Ipft1155Redeemable;

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
          ipft1155Redeemable.mint(
            w0.address,
            multihash.digest,
            10,
            false,
            expiresAt,
            []
          )
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
        const w0BalanceBefore = await ipft1155Redeemable.balanceOf(
          w0.address,
          multihash.digest
        );

        const totalSupplyBefore = await ipft1155Redeemable.totalSupply(
          multihash.digest
        );

        await ipft1155Redeemable.mint(
          w0.address,
          multihash.digest,
          10,
          false,
          expiresAt,
          []
        );

        expect(
          await ipft1155Redeemable.balanceOf(w0.address, multihash.digest)
        ).to.eq(w0BalanceBefore.add(10));

        expect(await ipft1155Redeemable.totalSupply(multihash.digest)).to.equal(
          totalSupplyBefore.add(10)
        );
      });
    });

    describe("when IPFT(721) is not possesed", () => {
      it("fails", async () => {
        await expect(
          ipft1155Redeemable
            .connect(w1)
            .mint(w1.address, multihash.digest, 10, false, expiresAt, [])
        ).to.be.revertedWith("IPFT(1155)Redeemable: IPFT(721)-unauthorized");
      });
    });

    describe("when IPFT(721) is authorized", () => {
      before(async () => {
        await ipft721.setApprovalForAll(w1.address, true);
      });

      it("works", async () => {
        const w1BalanceBefore = await ipft1155Redeemable.balanceOf(
          w1.address,
          multihash.digest
        );

        await ipft1155Redeemable
          .connect(w1)
          .mint(w1.address, multihash.digest, 10, false, expiresAt, []);

        expect(
          await ipft1155Redeemable
            .connect(w1)
            .balanceOf(w1.address, multihash.digest)
        ).to.equal(w1BalanceBefore.add(10));
      });
    });

    describe("when finalized", () => {
      before(async () => {
        await ipft1155Redeemable.mint(
          w0.address,
          multihash.digest,
          0,
          true,
          expiresAt,
          []
        );
      });

      it("fails", async () => {
        expect(await ipft1155Redeemable.isFinalized(multihash.digest)).to.be
          .true;

        await expect(
          ipft1155Redeemable.mint(
            w0.address,
            multihash.digest,
            10,
            false,
            expiresAt,
            []
          )
        ).to.be.revertedWith("IPFT(1155)Redeemable: finalized");
      });
    });
  });

  describe("redeeming", () => {
    it("works", async () => {
      const w0BalanceBefore = await ipft1155Redeemable.balanceOf(
        w0.address,
        multihash.digest
      );

      await expect(
        ipft1155Redeemable.safeTransferFrom(
          w0.address,
          ipft1155Redeemable.address,
          multihash.digest,
          3,
          []
        )
      )
        .to.emit(ipft1155Redeemable, "TransferSingle")
        .withArgs(
          w0.address,
          w0.address,
          ipft1155Redeemable.address,
          BigNumber.from(multihash.digest),
          3
        );

      expect(
        await ipft1155Redeemable.balanceOf(w0.address, multihash.digest)
      ).to.eq(w0BalanceBefore.sub(3));
    });

    describe("when expired", () => {
      before(async () => {
        await provider.send("evm_increaseTime", [
          addMonths(0, 2).valueOf() / 1000,
        ]);

        await provider.send("evm_mine", []);
      });

      it("fails", async () => {
        await expect(
          ipft1155Redeemable.safeTransferFrom(
            w0.address,
            ipft1155Redeemable.address,
            multihash.digest,
            3,
            []
          )
        ).to.be.revertedWith("IPFT(1155)Redeemable: expired");
      });
    });
  });
});
