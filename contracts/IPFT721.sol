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
    /// An IPFT content author.
    mapping(uint256 => address) _contentAuthor;

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
        return _contentAuthor[tokenId];
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
                    32
                ),
                "/metadata.json"
            );
    }

    /**
     * Claim, then mint an IPFT721.
     */
    function _mint(
        address to,
        uint256 contentId,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftTagOffset
    ) internal {
        _claim(contentId, contentAuthor, content, contentCodec, ipftTagOffset);
        _mint(to, contentId);
    }

    /**
     * See {ERC721-_safeMint}.
     */
    function _safeMint(
        address to,
        uint256 contentId,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftTagOffset
    ) internal {
        _safeMint(
            to,
            contentId,
            contentAuthor,
            content,
            contentCodec,
            ipftTagOffset,
            ""
        );
    }

    /**
     * See {ERC721-_safeMint}.
     */
    function _safeMint(
        address to,
        uint256 contentId,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftTagOffset,
        bytes memory mintData
    ) internal {
        _claim(contentId, contentAuthor, content, contentCodec, ipftTagOffset);
        _safeMint(to, contentId, mintData);
    }

    /**
     * Claim an IPFT721 authorship (see {LibIPFT.verifyTag}).
     *
     * @notice The content shall have an ERC721 Metadata JSON file resolvable
     * at the "/metadata.json" path. See {tokenURI} for a metadata URI example.
     *
     * @param contentId     The token id, also the keccak256 hash of `content`.
     * @param content       The file containing an IPFT tag.
     * @param contentCodec  The content multicodec (e.g. `0x71` for dag-cbor).
     * @param ipftTagOffset The IPFT tag offset in bytes.
     * @param contentAuthor The to-become-token-author address.
     */
    function _claim(
        uint256 contentId,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftTagOffset
    ) private {
        require(
            msg.sender == contentAuthor ||
                isApprovedForAll(contentAuthor, msg.sender),
            "IPFT721: unauthorized"
        );

        LibIPFT.verifyTag(
            content,
            ipftTagOffset,
            address(this),
            contentAuthor
        );

        // Check the content hash against the token ID.
        require(
            uint256(keccak256(content)) == contentId,
            "IPFT721: content hash mismatch"
        );

        // Set content author.
        _contentAuthor[contentId] = contentAuthor;

        // Set the multicodec.
        _contentCodec[contentId] = contentCodec;

        // Emit the IIPFT claim event.
        emit Claim(contentId, contentAuthor, contentCodec, 0x1b);
    }
}
