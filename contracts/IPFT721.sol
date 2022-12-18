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
     * See {IIPFT.contentAuthorOf}.
     */
    function contentAuthorOf(
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
     * Claim, then mint an IPFT721.
     */
    function _mint(
        address to,
        uint256 id,
        bytes calldata content,
        uint32 contentCodec,
        uint32 tagOffset,
        address author
    ) internal {
        _claim(id, content, contentCodec, tagOffset, author);
        _mint(to, id);
    }

    /**
     * See {ERC721-_safeMint}.
     */
    function _safeMint(
        address to,
        uint256 id,
        bytes calldata content,
        uint32 contentCodec,
        uint32 tagOffset,
        address author
    ) internal {
        _safeMint(to, id, content, contentCodec, tagOffset, author, "");
    }

    /**
     * See {ERC721-_safeMint}.
     */
    function _safeMint(
        address to,
        uint256 id,
        bytes calldata content,
        uint32 contentCodec,
        uint32 tagOffset,
        address author,
        bytes memory data
    ) internal {
        _claim(id, content, contentCodec, tagOffset, author);
        _safeMint(to, id, data);
    }

    /**
     * Claim an IPFT721 authorship (see {LibIPFT.verifyTag}).
     *
     * @notice The content shall have an ERC721 Metadata JSON file resolvable
     * at the "/metadata.json" path. See {tokenURI} for a metadata URI example.
     *
     * @param id           The token id, also the keccak256 hash of `content`.
     * @param content      The file containing an IPFT tag.
     * @param contentCodec The content multicodec (e.g. `0x71` for dag-cbor).
     * @param tagOffset    The IPFT tag offset in bytes.
     * @param author       The to-become-token-author address.
     */
    function _claim(
        uint256 id,
        bytes calldata content,
        uint32 contentCodec,
        uint32 tagOffset,
        address author
    ) private {
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
    }
}
