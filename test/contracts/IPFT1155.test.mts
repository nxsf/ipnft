import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import IpftABI from "../../waffle/IPFT.json";
import { Ipft } from "../../waffle/types/Ipft";
import Ipft1155ABI from "../../waffle/IPFT1155.json";
import { Ipft1155 } from "../../waffle/types/Ipft1155";
import * as DagCbor from "@ipld/dag-cbor";
import { ByteView, CID, digest } from "multiformats";
import { sha256 } from "multiformats/hashes/sha2";
import { ipftTag, getChainId } from "./util.mjs";
import { addMonths } from "date-fns";
import { BigNumber } from "ethers";

use(solidity);

describe("IPFT(1155)", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let ipft721: Ipft;
  let ipft1155: Ipft1155;

  let content: ByteView<any>, multihash: digest.Digest<18, number>;
  let expiresAt = Math.round(addMonths(new Date(), 1).valueOf() / 1000);

  before(async () => {
    ipft721 = (await deployContract(w0, IpftABI)) as Ipft;

    ipft1155 = (await deployContract(w0, Ipft1155ABI, [
      ipft721.address,
    ])) as Ipft1155;

    content = DagCbor.encode({
      metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
      ipft: ipftTag(await getChainId(provider), ipft721.address, w0.address, 0),
    });

    multihash = await sha256.digest(content);
  });

  describe("minting", () => {
    describe("when IPFT(721) doesn't exist", () => {
      it("fails", async () => {
        await expect(
          ipft1155.mint(w0.address, multihash.digest, 10, false, expiresAt, [])
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

        await ipft1155.mint(
          w0.address,
          multihash.digest,
          10,
          false,
          expiresAt,
          []
        );

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
          ipft1155
            .connect(w1)
            .mint(w1.address, multihash.digest, 10, false, expiresAt, [])
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
          .mint(w1.address, multihash.digest, 10, false, expiresAt, []);

        expect(
          await ipft1155.connect(w1).balanceOf(w1.address, multihash.digest)
        ).to.equal(w1BalanceBefore.add(10));
      });
    });

    describe("when finalized", () => {
      before(async () => {
        await ipft1155.mint(
          w0.address,
          multihash.digest,
          0,
          true,
          expiresAt,
          []
        );
      });

      it("fails", async () => {
        expect(await ipft1155.isFinalized(multihash.digest)).to.be.true;

        await expect(
          ipft1155.mint(w0.address, multihash.digest, 10, false, expiresAt, [])
        ).to.be.revertedWith("IPFT(1155): finalized");
      });
    });
  });

  describe("redeeming", () => {
    it("works", async () => {
      const w0BalanceBefore = await ipft1155.balanceOf(
        w0.address,
        multihash.digest
      );

      await expect(
        ipft1155.safeTransferFrom(
          w0.address,
          ipft1155.address,
          multihash.digest,
          3,
          []
        )
      )
        .to.emit(ipft1155, "TransferSingle")
        .withArgs(
          w0.address,
          w0.address,
          ipft1155.address,
          BigNumber.from(multihash.digest),
          3
        );

      expect(await ipft1155.balanceOf(w0.address, multihash.digest)).to.eq(
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
          ipft1155.safeTransferFrom(
            w0.address,
            ipft1155.address,
            multihash.digest,
            3,
            []
          )
        ).to.be.revertedWith("IPFT(1155): expired");
      });
    });
  });
});
