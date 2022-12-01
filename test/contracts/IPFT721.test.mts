// This test also covers "IPFT.sol".
//

import { expect, use } from "chai";
import { ethers } from "ethers";
import { deployContract, MockProvider, solidity, link } from "ethereum-waffle";
import IpftABI from "../../waffle/IPFT.json";
import Ipft721ABI from "../../waffle/IPFT721.json";
import { Ipft721 } from "../../waffle/types/Ipft721.js";
import * as DagCbor from "@ipld/dag-cbor";
import { keccak256 } from "@multiformats/sha3";
import { CID } from "multiformats";
import { IPFTTag, getChainId } from "./util.mjs";

use(solidity);

describe("IPFT(721)", async () => {
  const provider = new MockProvider();
  const [w0, w1, w2] = provider.getWallets();

  let ipft721: Ipft721;

  before(async () => {
    const ipft = await deployContract(w0, IpftABI);
    link(Ipft721ABI, "src/contracts/IPFT.sol:IPFT", ipft.address);
    ipft721 = (await deployContract(w0, Ipft721ABI)) as Ipft721;
  });

  describe("minting", () => {
    it("fails on invalid tag offset", async () => {
      const content = DagCbor.encode({
        metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
        ipft: new IPFTTag(
          await getChainId(provider),
          ipft721.address,
          w0.address,
          0
        ).toBytes(),
      });

      const multihash = await keccak256.digest(content);

      await expect(
        ipft721.claimMint(multihash.digest, w0.address, {
          author: w0.address,
          content,
          tagOffset: 9, // This
          codec: DagCbor.code,
          royalty: 10,
        })
      ).to.be.revertedWith("IPFT: invalid magic bytes");
    });

    it("works", async () => {
      const content = DagCbor.encode({
        metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
        ipft: new IPFTTag(
          await getChainId(provider),
          ipft721.address,
          w0.address,
          0
        ).toBytes(),
      });

      const multihash = await keccak256.digest(content);

      expect(
        await ipft721.claimMint(multihash.digest, w0.address, {
          author: w0.address,
          content,
          tagOffset: 8,
          codec: DagCbor.code,
          royalty: 10,
        })
      ).to.emit(ipft721, "Claim");
      // TODO: .withArgs(w0.address, w0.address, multihash.digest, DagCbor.code);

      expect(await ipft721.balanceOf(w0.address)).to.eq(1);
      expect(await ipft721.ownerOf(multihash.digest)).to.eq(w0.address);
      expect(await ipft721.codec(multihash.digest)).to.eq(DagCbor.code);
      expect(await ipft721.authorNonce(w0.address)).to.eq(1);

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
        ipft: new IPFTTag(
          await getChainId(provider),
          ipft721.address,
          w0.address,
          0 // This
        ).toBytes(),
      });

      const multihash = await keccak256.digest(content);

      await expect(
        ipft721.claimMint(multihash.digest, w0.address, {
          author: w0.address,
          content,
          tagOffset: 8,
          codec: DagCbor.code,
          royalty: 10,
        })
      ).to.be.revertedWith("IPFT: invalid nonce");
    });
  });

  describe("uri", () => {
    it("works", async () => {
      const content = DagCbor.encode({
        metadata: CID.parse("QmaozNR7DZHQK1ZcU9p7QdrshMvXqWK6gpu5rmrkPdT3L4"),
        ipft: new IPFTTag(
          await getChainId(provider),
          ipft721.address,
          w0.address,
          0
        ).toBytes(),
      });

      const multihash = await keccak256.digest(content);

      expect(await ipft721.tokenURI(multihash.digest)).to.eq(
        "http://f01711b20{id}.ipfs/metadata.json"
      );
    });
  });
});
