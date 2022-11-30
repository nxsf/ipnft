// This test also covers "IPFT.sol".
//

import { expect, use } from "chai";
import { ethers } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import ABI from "../../waffle/IPFT721.json";
import { Ipft721 } from "../../waffle/types/Ipft721.js";
import * as DagCbor from "@ipld/dag-cbor";
import { keccak256 } from "@multiformats/sha3";
import { CID } from "multiformats";
import { ipftTag, getChainId } from "./util.mjs";

use(solidity);

describe("IPFT(721)", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let ipft721: Ipft721;

  before(async () => {
    ipft721 = (await deployContract(w0, ABI)) as Ipft721;
  });

  describe("minting", () => {
    it("fails on invalid tag offset", async () => {
      const content = DagCbor.encode({
        metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
        ipft: ipftTag(
          await getChainId(provider),
          ipft721.address,
          w0.address,
          0
        ),
      });

      const multihash = await keccak256.digest(content);

      await expect(
        ipft721.mint(
          w0.address,
          multihash.digest,
          content,
          9, // This
          DagCbor.code,
          0
        )
      ).to.be.revertedWith("IPFT: invalid tag version");
    });

    it("works", async () => {
      const content = DagCbor.encode({
        metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
        ipft: ipftTag(
          await getChainId(provider),
          ipft721.address,
          w0.address,
          0
        ),
      });

      const multihash = await keccak256.digest(content);

      await ipft721.mint(
        w0.address,
        multihash.digest,
        content,
        8,
        DagCbor.code,
        10
      );

      expect(await ipft721.balanceOf(w0.address)).to.eq(1);
      expect(await ipft721.ownerOf(multihash.digest)).to.eq(w0.address);
      expect(await ipft721.nonce(w0.address)).to.eq(1);

      const royaltyInfo = await ipft721.royaltyInfo(
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
        ipft: ipftTag(
          await getChainId(provider),
          ipft721.address,
          w0.address,
          0 // This
        ),
      });

      const multihash = await keccak256.digest(content);

      await expect(
        ipft721.mint(w0.address, multihash.digest, content, 8, DagCbor.code, 10)
      ).to.be.revertedWith("IPFT: invalid nonce");
    });
  });

  describe("uri", () => {
    it("works", async () => {
      const content = DagCbor.encode({
        metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
        ipft: ipftTag(
          await getChainId(provider),
          ipft721.address,
          w0.address,
          0
        ),
      });

      const multihash = await keccak256.digest(content);

      expect(await ipft721.tokenURI(multihash.digest)).to.eq(
        "http://f01711b20{id}.ipfs/metadata.json"
      );
    });
  });
});