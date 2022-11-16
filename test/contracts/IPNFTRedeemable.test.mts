import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import IpnftABI from "../../waffle/IPNFT.json";
import { Ipnft } from "../../waffle/types/Ipnft";
import IpnftRedeemableABI from "../../waffle/IPNFTRedeemable.json";
import { IpnftRedeemable } from "../../waffle/types/IpnftRedeemable";
import * as DagCbor from "@ipld/dag-cbor";
import { ByteView, CID, digest } from "multiformats";
import { sha256 } from "multiformats/hashes/sha2";
import { ipnftTag, getChainId } from "./util.mjs";
import { addMonths } from "date-fns";
import { BigNumber } from "ethers";

use(solidity);

describe("IPNFTRedeemable", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let ipnft: Ipnft;
  let redeemable: IpnftRedeemable;

  let content: ByteView<any>, multihash: digest.Digest<18, number>;
  let expiresAt = Math.round(addMonths(new Date(), 1).valueOf() / 1000);

  before(async () => {
    ipnft = (await deployContract(w0, IpnftABI)) as Ipnft;

    redeemable = (await deployContract(w0, IpnftRedeemableABI, [
      ipnft.address,
    ])) as IpnftRedeemable;

    content = DagCbor.encode({
      metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
      ipnft: ipnftTag(await getChainId(provider), ipnft.address, w0.address, 0),
    });

    multihash = await sha256.digest(content);
  });

  describe("minting", () => {
    describe("when IPNFT doesn't exist", () => {
      it("fails", async () => {
        await expect(
          redeemable.mint(
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
        await ipnft.mint(w0.address, multihash.digest, content, 9, 10);
      });
    });

    describe("when IPNFT is owned", () => {
      it("works", async () => {
        const w0BalanceBefore = await redeemable.balanceOf(
          w0.address,
          multihash.digest
        );

        const totalSupplyBefore = await redeemable.totalSupply(
          multihash.digest
        );

        await redeemable.mint(
          w0.address,
          multihash.digest,
          10,
          false,
          expiresAt,
          []
        );

        expect(await redeemable.balanceOf(w0.address, multihash.digest)).to.eq(
          w0BalanceBefore.add(10)
        );

        expect(await redeemable.totalSupply(multihash.digest)).to.equal(
          totalSupplyBefore.add(10)
        );
      });
    });

    describe("when IPNFT is not possesed", () => {
      it("fails", async () => {
        await expect(
          redeemable
            .connect(w1)
            .mint(w1.address, multihash.digest, 10, false, expiresAt, [])
        ).to.be.revertedWith("IPNFTRedeemable: IPNFT-unauthorized");
      });
    });

    describe("when IPNFT is authorized", () => {
      before(async () => {
        await ipnft.setApprovalForAll(w1.address, true);
      });

      it("works", async () => {
        const w1BalanceBefore = await redeemable.balanceOf(
          w1.address,
          multihash.digest
        );

        await redeemable
          .connect(w1)
          .mint(w1.address, multihash.digest, 10, false, expiresAt, []);

        expect(
          await redeemable.connect(w1).balanceOf(w1.address, multihash.digest)
        ).to.equal(w1BalanceBefore.add(10));
      });
    });

    describe("when finalized", () => {
      before(async () => {
        await redeemable.mint(
          w0.address,
          multihash.digest,
          0,
          true,
          expiresAt,
          []
        );
      });

      it("fails", async () => {
        expect(await redeemable.isFinalized(multihash.digest)).to.be.true;

        await expect(
          redeemable.mint(
            w0.address,
            multihash.digest,
            10,
            false,
            expiresAt,
            []
          )
        ).to.be.revertedWith("IPNFTRedeemable: finalized");
      });
    });
  });

  describe("redeeming", () => {
    it("works", async () => {
      const w0BalanceBefore = await redeemable.balanceOf(
        w0.address,
        multihash.digest
      );

      await expect(
        redeemable.safeTransferFrom(
          w0.address,
          redeemable.address,
          multihash.digest,
          3,
          []
        )
      )
        .to.emit(redeemable, "TransferSingle")
        .withArgs(
          w0.address,
          w0.address,
          redeemable.address,
          BigNumber.from(multihash.digest),
          3
        );

      expect(await redeemable.balanceOf(w0.address, multihash.digest)).to.eq(
        w0BalanceBefore.sub(3)
      );
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
          redeemable.safeTransferFrom(
            w0.address,
            redeemable.address,
            multihash.digest,
            3,
            []
          )
        ).to.be.revertedWith("IPNFTRedeemable: expired");
      });
    });
  });
});
