// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "./LibIPFT.sol";
import "./IIPFT.sol";

/**
 * @title Interplanetary File Token (1155)
 * @author Onyx Software Foundation <nxsf.org>
 *
 * An IPFT1155 represents a ERC1155-compliant digital copyright for an IPFS CID,
 * where a token ID is the 32-byte keccak256 digest part of it.
 *
 * To {_claim} an IPFT1155 with a specific identifier, one must prove
 * the authorship of the content containing a valid IPFT tag.
 *
 * Only after claiming an IPFT1155, it can be {_mint}ed.
 */
contract IPFT1155 is ERC1155, IIPFT {
    /// An IPFT author.
    mapping(uint256 => address) _author;

    /// An IPFT content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) _contentCodec;

    constructor() ERC1155("") {}

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
     * Always returns 0x1b (keccak-256).
     * See {IIPFT.multihashCodecOf}.
     */
    function multihashCodecOf(
        uint256
    ) public pure override(IIPFT) returns (uint32) {
        return 0x1b;
    }

    /**
     * Always returns 32.
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
    function uri(
        uint256 id
    ) public view override(ERC1155) returns (string memory) {
        return
            string.concat(
                LibIPFT.uri(
                    contentCodecOf(id),
                    multihashCodecOf(id),
                    multihashDigestSizeOf(id)
                ),
                "/metadata.json"
            );
    }

    /**
     * Claim an IPFT authorship by verifying that `content` contains
     * a valid IPFT tag at `offset`. See {LibIPFT.verifyTag} for more details.
     * Once claimed, the token may be {_mint}ed.
     *
     * @notice The content shall have an ERC1155 Metadata JSON file resolvable
     * at the "/metadata.json" path. See {uri} for a metadata URI example.
     *
     * @param id           The token ID, also the keccak256 hash of `content`.
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
    ) internal {
        require(
            msg.sender == author || isApprovedForAll(author, msg.sender),
            "IPFT1155: unauthorized"
        );

        require(_author[id] == address(0), "IPFT1155: already claimed");

        LibIPFT.verifyTag(content, tagOffset, address(this), author);
        require(uint256(keccak256(content)) == id, "IPFT1155: hash mismatch");

        _author[id] = author;
        _contentCodec[id] = contentCodec;

        emit Claim(author, contentCodec, 0x1b, 32, abi.encodePacked(id));
    }

    /**
     * Mint a previously {_claim}ed IPFT1155 token.
     * Ensures the caller is authorized.
     */
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) internal override(ERC1155) {
        require(
            _author[id] == msg.sender ||
                isApprovedForAll(_author[id], msg.sender),
            "IPFT1155: unauthorized"
        );

        super._mint(to, id, amount, data);
    }

    /**
     * Batch version of {_mint}.
     */
    function _mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) internal override(ERC1155) {
        for (uint256 i = 0; i < ids.length; i++) {
            require(
                _author[ids[i]] == msg.sender ||
                    isApprovedForAll(_author[ids[i]], msg.sender),
                "IPFT1155: unauthorized"
            );
        }

        super._mintBatch(to, ids, amounts, data);
    }
}
