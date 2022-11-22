import { expect, use } from "chai";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import IpnftABI from "../../waffle/IPNFT.json";
import { Ipnft } from "../../waffle/types/Ipnft";
import Ipnft1155ABI from "../../waffle/IPNFT1155.json";
import { Ipnft1155 } from "../../waffle/types/Ipnft1155";
import * as DagCbor from "@ipld/dag-cbor";
import { ByteView, CID, digest } from "multiformats";
import { sha256 } from "multiformats/hashes/sha2";
import { ipnftTag, getChainId } from "./util.mjs";
import { addMonths } from "date-fns";
import { BigNumber } from "ethers";
import { AddressZero } from "@ethersproject/constants";

use(solidity);

describe("IPNFT1155", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let ipnft721: Ipnft;
  let ipnft1155: Ipnft1155;

  let content0: ByteView<any>, multihash0: digest.Digest<18, number>;
  let content1: ByteView<any>, multihash1: digest.Digest<18, number>;
  let expiresAt = Math.round(addMonths(new Date(), 1).valueOf() / 1000);

  before(async () => {
    ipnft721 = (await deployContract(w0, IpnftABI)) as Ipnft;

    ipnft1155 = (await deployContract(w0, Ipnft1155ABI, [
      ipnft721.address,
    ])) as Ipnft1155;

    content0 = DagCbor.encode({
      metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
      ipnft: ipnftTag(
        await getChainId(provider),
        ipnft721.address,
        w0.address,
        0
      ),
    });

    multihash0 = await sha256.digest(content0);

    content1 = DagCbor.encode({
      metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
      ipnft: ipnftTag(
        await getChainId(provider),
        ipnft721.address,
        w0.address,
        1
      ),
    });

    multihash1 = await sha256.digest(content1);
  });

  describe("minting", () => {
    describe("when IPNFT doesn't exist", () => {
      it("fails", async () => {
        await expect(
          ipnft1155.mint(
            w0.address,
            multihash0.digest,
            10,
            AddressZero,
            false,
            expiresAt,
            []
          )
        ).to.be.revertedWith("ERC721: invalid token ID");
      });

      after(async () => {
        await ipnft721.mint(w0.address, multihash0.digest, content0, 9, 10);
      });
    });

    describe("when IPNFT is owned", () => {
      it("works", async () => {
        const w0BalanceBefore = await ipnft1155.balanceOf(
          w0.address,
          multihash0.digest
        );

        const totalSupplyBefore = await ipnft1155.totalSupply(
          multihash0.digest
        );

        await ipnft1155.mint(
          w0.address,
          multihash0.digest,
          10,
          AddressZero,
          false,
          expiresAt,
          []
        );

        expect(await ipnft1155.balanceOf(w0.address, multihash0.digest)).to.eq(
          w0BalanceBefore.add(10)
        );

        expect(await ipnft1155.totalSupply(multihash0.digest)).to.equal(
          totalSupplyBefore.add(10)
        );
      });
    });

    describe("when IPNFT is not possesed", () => {
      it("fails", async () => {
        await expect(
          ipnft1155
            .connect(w1)
            .mint(
              w1.address,
              multihash0.digest,
              10,
              AddressZero,
              false,
              expiresAt,
              []
            )
        ).to.be.revertedWith("IPNFT1155: IPNFT721-unauthorized");
      });
    });

    describe("when IPNFT is authorized", () => {
      before(async () => {
        await ipnft721.setApprovalForAll(w1.address, true);
      });

      it("works", async () => {
        const w1BalanceBefore = await ipnft1155.balanceOf(
          w1.address,
          multihash0.digest
        );

        await ipnft1155
          .connect(w1)
          .mint(
            w1.address,
            multihash0.digest,
            10,
            AddressZero,
            false,
            expiresAt,
            []
          );

        expect(
          await ipnft1155.connect(w1).balanceOf(w1.address, multihash0.digest)
        ).to.equal(w1BalanceBefore.add(10));
      });
    });

    describe("when finalized", () => {
      before(async () => {
        await ipnft1155.mint(
          w0.address,
          multihash0.digest,
          0,
          AddressZero,
          true,
          expiresAt,
          []
        );
      });

      it("fails", async () => {
        expect(await ipnft1155.isFinalized(multihash0.digest)).to.be.true;

        await expect(
          ipnft1155.mint(
            w0.address,
            multihash0.digest,
            10,
            AddressZero,
            false,
            expiresAt,
            []
          )
        ).to.be.revertedWith("IPNFT1155: finalized");
      });
    });

    describe("with collection", () => {
      before(async () => {
        await ipnft721.mint(w0.address, multihash1.digest, content1, 9, 11);
        await ipnft721.approve(w1.address, multihash1.digest);
      });

      describe("when collection is not approved", () => {
        it("fails", async () => {
          await expect(
            ipnft1155
              .connect(w1)
              .mint(
                w1.address,
                multihash1.digest,
                10,
                w0.address,
                false,
                expiresAt,
                []
              )
          ).to.be.revertedWith("IPNFT1155: collection unauthorized");
        });
      });

      describe("when collection is approved", () => {
        before(async () => {
          await ipnft1155.setApprovalForAll(w1.address, true);
        });

        it("works", async () => {
          for (let i = 0; i < 2; i++) {
            const w1BalanceBefore = await ipnft1155.balanceOf(
              w1.address,
              multihash1.digest
            );

            await ipnft1155
              .connect(w1)
              .mint(
                w1.address,
                multihash1.digest,
                10,
                w0.address,
                false,
                expiresAt,
                []
              );

            expect(
              await ipnft1155.balanceOf(w1.address, multihash1.digest)
            ).to.equal(w1BalanceBefore.add(10));
          }
        });

        it("requires the same collection", async () => {
          await expect(
            ipnft1155
              .connect(w1)
              .mint(
                w1.address,
                multihash1.digest,
                10,
                w1.address,
                false,
                expiresAt,
                []
              )
          ).to.be.revertedWith("IPNFT1155: collection mismatch");
        });
      });
    });
  });

  describe("redeeming", () => {
    it("works", async () => {
      const w0BalanceBefore = await ipnft1155.balanceOf(
        w0.address,
        multihash0.digest
      );

      await expect(
        ipnft1155.safeTransferFrom(
          w0.address,
          ipnft1155.address,
          multihash0.digest,
          3,
          []
        )
      )
        .to.emit(ipnft1155, "TransferSingle")
        .withArgs(
          w0.address,
          w0.address,
          ipnft1155.address,
          BigNumber.from(multihash0.digest),
          3
        );

      expect(await ipnft1155.balanceOf(w0.address, multihash0.digest)).to.eq(
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
          ipnft1155.safeTransferFrom(
            w0.address,
            ipnft1155.address,
            multihash0.digest,
            3,
            []
          )
        ).to.be.revertedWith("IPNFT1155: expired");
      });
    });
  });
});
