import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import IpftRedeemableABI from "../../waffle/IPFTRedeemable.json";
import { IpftRedeemable } from "../../waffle/types/IpftRedeemable";
import * as DagCbor from "@ipld/dag-cbor";
import { ByteView, CID, digest } from "multiformats";
import { keccak256 } from "@multiformats/sha3";
import { ipftTag, getChainId } from "./util.mjs";
import { addMonths } from "date-fns";
import { BigNumber } from "ethers";

use(solidity);

describe("IPFT(Redeemable)", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let ipft1155Redeemable: IpftRedeemable;
  let content: ByteView<any>;
  let multihash: digest.Digest<27, number>;
  let expiresAt = Math.round(addMonths(new Date(), 1).valueOf() / 1000);

  before(async () => {
    ipft1155Redeemable = (await deployContract(
      w0,
      IpftRedeemableABI
    )) as IpftRedeemable;

    content = DagCbor.encode({
      metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
      ipft: ipftTag(
        await getChainId(provider),
        ipft1155Redeemable.address,
        w0.address,
        0
      ),
    });

    multihash = await keccak256.digest(content);
  });

  describe("minting", () => {
    describe("when not claimed", () => {
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
        ).to.be.revertedWith("IPFT(Redeemable): unauthorized");
      });

      after(async () => {
        await ipft1155Redeemable.claim(
          w0.address,
          multihash.digest,
          content,
          8,
          DagCbor.code,
          10
        );
      });
    });

    describe("when claimed", () => {
      it("works", async () => {
        const w0BalanceBefore = await ipft1155Redeemable.balanceOf(
          w0.address,
          multihash.digest
        );

        const totalSupplyBefore = await ipft1155Redeemable.totalSupply(
          multihash.digest
        );

        // TODO: Test `Claim` event.
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

    describe("when not the owner", () => {
      it("fails", async () => {
        await expect(
          ipft1155Redeemable
            .connect(w1)
            .mint(w1.address, multihash.digest, 10, false, expiresAt, [])
        ).to.be.revertedWith("IPFT(Redeemable): unauthorized");
      });
    });

    describe("when set approval for all", () => {
      before(async () => {
        await ipft1155Redeemable.setApprovalForAll(w1.address, true);
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
        ).to.be.revertedWith("IPFT(Redeemable): finalized");
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
        ).to.be.revertedWith("IPFT(Redeemable): expired");
      });
    });
  });

  describe("claim-minting", () => {
    it("works", async () => {
      let content1 = DagCbor.encode({
        metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
        ipft: ipftTag(
          await getChainId(provider),
          ipft1155Redeemable.address,
          w0.address,
          1
        ),
      });

      let multihash1 = await keccak256.digest(content1);

      const w1BalanceBefore = await ipft1155Redeemable.balanceOf(
        w1.address,
        multihash1.digest
      );

      const totalSupplyBefore = await ipft1155Redeemable.totalSupply(
        multihash1.digest
      );

      await ipft1155Redeemable.claimMint(content1, [], {
        author: w0.address,
        id: multihash1.digest,
        offset: 8,
        codec: DagCbor.code,
        royalty: 10,
        to: w1.address,
        amount: 10,
        finalize: false,
        expiredAt: Math.round(addMonths(new Date(), 2).valueOf() / 1000),
      });

      expect(
        await ipft1155Redeemable.balanceOf(w1.address, multihash1.digest)
      ).to.eq(w1BalanceBefore.add(10));

      expect(await ipft1155Redeemable.totalSupply(multihash1.digest)).to.equal(
        totalSupplyBefore.add(10)
      );
    });
  });
});
