// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./LibIPNFT.sol";
import "./IIPNFT.sol";

/**
 * @title Interplanetary Non-fungible File Token (721)
 * @author Onyx Software Foundation <nxsf.org>
 *
 * An IPNFT721 represents a ERC721-compliant digital copyright for an IPFS CID,
 * where a token ID is the 32-byte keccak256 digest part of it.
 *
 * To {_mint} an IPNFT721 with a specific identifier, one must prove
 * the authorship of the content containing a valid IP(N)FT tag.
 */
contract IPNFT721 is ERC721, IIPNFT {
    /// An IPNFT content author.
    mapping(uint256 => address) private _contentAuthor;

    /// An IPNFT content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) private _contentCodec;

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    /**
     * See {IIPNFT.contentIdOf}.
     */
    function contentIdOf(
        uint256 tokenId
    ) public pure override(IIPNFT) returns (bytes32) {
        return bytes32(tokenId);
    }

    /**
     * See {IIPNFT.contentAuthorOf}.
     */
    function contentAuthorOf(
        uint256 tokenId
    ) public view override(IIPNFT) returns (address) {
        return _contentAuthor[tokenId];
    }

    /**
     * See {IIPNFT.contentCodecOf}.
     */
    function contentCodecOf(
        uint256 tokenId
    ) public view override(IIPNFT) returns (uint32) {
        return _contentCodec[tokenId];
    }

    /**
     * Always return 0x1b (keccak-256).
     * See {IIPNFT.multihashCodecOf}.
     */
    function multihashCodecOf(
        uint256
    ) public pure override(IIPNFT) returns (uint32) {
        return 0x1b;
    }

    /**
     * Return {IPNFT.uri} + "/metadata.json".
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721) returns (string memory) {
        return
            string.concat(
                LibIPNFT.uri(
                    contentCodecOf(tokenId),
                    multihashCodecOf(tokenId),
                    32
                ),
                "/metadata.json"
            );
    }

    /**
     * {_claim}, then mint an IPNFT721.
     */
    function _mint(
        address to,
        uint256 contentId,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftOffset
    ) internal {
        _claim(contentId, contentAuthor, content, contentCodec, ipftOffset);
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
        uint32 ipftOffset
    ) internal {
        _safeMint(
            to,
            contentId,
            contentAuthor,
            content,
            contentCodec,
            ipftOffset,
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
        uint32 ipftOffset,
        bytes memory mintData
    ) internal {
        _claim(contentId, contentAuthor, content, contentCodec, ipftOffset);
        _safeMint(to, contentId, mintData);
    }

    /**
     * Claim an IPNFT721 authorship by proving that `content`
     * contains a valid IPFT[^1] (see {LibIPNFT.verifyIpft}).
     *
     * @notice The content shall have an ERC721 Metadata JSON file resolvable
     * at the "/metadata.json" path. See {tokenURI} for a metadata URI example.
     *
     * @param contentId     The token id, also the keccak256 hash of `content`.
     * @param contentAuthor The to-become-token-author address.
     * @param content       The file containing an IPFT.
     * @param contentCodec  The content multicodec (e.g. `0x71` for dag-cbor).
     * @param ipftOffset    The IPFT offset in bytes.
     *
     * [^1]: Interplanetary File Tag.
     */
    function _claim(
        uint256 contentId,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftOffset
    ) private {
        require(
            msg.sender == contentAuthor ||
                isApprovedForAll(contentAuthor, msg.sender),
            "IPNFT721: unauthorized"
        );

        LibIPNFT.verifyIpft(content, ipftOffset, address(this), contentAuthor);
        require(
            uint256(keccak256(content)) == contentId,
            "IPNFT721: content hash mismatch"
        );

        // Set content author.
        _contentAuthor[contentId] = contentAuthor;

        // Set the multicodec.
        _contentCodec[contentId] = contentCodec;

        // Emit the IIPNFT claim event.
        emit Claim(
            contentIdOf(contentId),
            contentAuthor,
            contentCodec,
            multihashCodecOf(contentId)
        );
    }
}
