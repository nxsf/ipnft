import { expect, use } from "chai";
import { ethers } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import ABI from "../../waffle/IPNFT.json";
import { Ipnft } from "../../waffle/types/Ipnft";
import * as DagCbor from "@ipld/dag-cbor";
import { CID } from "multiformats";
import { sha256 } from "multiformats/hashes/sha2";
import { ipnftTag, getChainId } from "./util.mjs";

use(solidity);

describe("IPNFT", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let ipnft: Ipnft;

  before(async () => {
    ipnft = (await deployContract(w0, ABI)) as Ipnft;
  });

  describe("minting", () => {
    it("fails on invalid tag offset", async () => {
      const content = DagCbor.encode({
        metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
        ipnft: ipnftTag(
          await getChainId(provider),
          ipnft.address,
          w0.address,
          0
        ),
      });

      const multihash = await sha256.digest(content);

      await expect(
        ipnft.mint(
          w0.address,
          multihash.digest,
          content,
          10, // This
          0
        )
      ).to.be.revertedWith("IPNFT: invalid tag version");
    });

    it("works", async () => {
      const content = DagCbor.encode({
        metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
        ipnft: ipnftTag(
          await getChainId(provider),
          ipnft.address,
          w0.address,
          0
        ),
      });

      const multihash = await sha256.digest(content);

      await ipnft.mint(w0.address, multihash.digest, content, 9, 10);

      expect(await ipnft.balanceOf(w0.address)).to.eq(1);
      expect(await ipnft.ownerOf(multihash.digest)).to.eq(w0.address);
      expect(await ipnft.minterNonce(w0.address)).to.eq(1);

      const royaltyInfo = await ipnft.royaltyInfo(
        multihash.digest,
        ethers.utils.parseEther("1")
      );

      expect(royaltyInfo.receiver).to.eq(w0.address);
      expect(royaltyInfo.royaltyAmount).to.eq(
        ethers.utils.parseEther("0.039215686274509803")
      );
    });

    it("disallows minting with the sames nonce", async () => {
      const content = DagCbor.encode({
        metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
        ipnft: ipnftTag(
          await getChainId(provider),
          ipnft.address,
          w0.address,
          0 // This
        ),
      });

      const multihash = await sha256.digest(content);

      await expect(
        ipnft.mint(w0.address, multihash.digest, content, 9, 10)
      ).to.be.revertedWith("IPNFT: invalid minter nonce");
    });
  });

  describe("uri", () => {
    it("works", async () => {
      expect(await ipnft.tokenURI(0)).to.eq(
        "http://f01711220{id}.ipfs/metadata.json"
      );
    });
  });
});
