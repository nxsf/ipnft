// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./LibIPFT.sol";
import "./IIPFT.sol";

/**
 * @title Interplanetary File Token (721)
 * @author Onyx Software Foundation <nxsf.org>
 *
 * An IPFT721 represents a ERC721-compliant digital copyright for an IPFS CID,
 * where a token ID is the 32-byte keccak256 digest part of it.
 *
 * To {_mint} an IPFT721 with a specific identifier, one must prove
 * the authorship of the content containing a valid IPFT tag.
 */
contract IPFT721 is ERC721, IIPFT {
    /// An IPFT author.
    mapping(uint256 => address) _author;

    /// An IPFT content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) _contentCodec;

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    /**
     * See {IIPFT.authorOf}.
     */
    function authorOf(
        uint256 tokenId
    ) public view override(IIPFT) returns (address) {
        return _author[tokenId];
    }

    /**
     * See {IIPFT.contentCodecOf}.
     */
    function contentCodecOf(
        uint256 tokenId
    ) public view override(IIPFT) returns (uint32) {
        return _contentCodec[tokenId];
    }

    /**
     * Always return 0x1b (keccak-256).
     * See {IIPFT.multihashCodecOf}.
     */
    function multihashCodecOf(
        uint256
    ) public pure override(IIPFT) returns (uint32) {
        return 0x1b;
    }

    /**
     * Always return 32.
     * See {IIPFT.multihashDigestSizeOf}.
     */
    function multihashDigestSizeOf(
        uint256
    ) public pure override(IIPFT) returns (uint32) {
        return 32;
    }

    /**
     * Return the token ID as the multihash digest.
     * See {IIPFT.multihashDigestOf}.
     */
    function multihashDigestOf(
        uint256 tokenId
    ) external pure override(IIPFT) returns (bytes memory) {
        return abi.encodePacked(tokenId);
    }

    /**
     * Return {IPFT.uri} + "/metadata.json".
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721) returns (string memory) {
        return
            string.concat(
                LibIPFT.uri(
                    contentCodecOf(tokenId),
                    multihashCodecOf(tokenId),
                    multihashDigestSizeOf(tokenId)
                ),
                "/metadata.json"
            );
    }

    /**
     * Mint an IPFT721 by proving its authorship (see {LibIPFT.verifyTag}).
     * Upon success, a brand-new IPFT721 is minted to `to`.
     *
     * @notice The content shall have an ERC721 Metadata JSON file resolvable
     * at the "/metadata.json" path. See {tokenURI} for a metadata URI example.
     *
     * @param to           The address to mint the token to.
     * @param id           The token id, also the keccak256 hash of `content`.
     * @param content      The file containing an IPFT tag.
     * @param contentCodec The content multicodec (e.g. `0x71` for dag-cbor).
     * @param tagOffset    The IPFT tag offset in bytes.
     * @param author       The to-become-token-author address.
     */
    function _mint(
        address to,
        uint256 id,
        bytes calldata content,
        uint32 contentCodec,
        uint32 tagOffset,
        address author
    ) internal {
        require(
            msg.sender == author || isApprovedForAll(author, msg.sender),
            "IPFT721: unauthorized"
        );

        LibIPFT.verifyTag(content, tagOffset, address(this), author);

        // Check the content hash against the token ID.
        require(
            uint256(keccak256(content)) == id,
            "IPFT721: content hash mismatch"
        );

        // Set author.
        _author[id] = author;

        // Set the multicodec.
        _contentCodec[id] = contentCodec;

        // Emit the IIPFT claim event.
        emit Claim(author, contentCodec, 0x1b, 32, abi.encodePacked(id));

        // Mint the IPFT721.
        _mint(to, id);
    }
}
