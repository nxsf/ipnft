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
    /// An IPFT content author.
    mapping(uint256 => address) _contentAuthor;

    /// An IPFT content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) _contentCodec;

    constructor() ERC1155("") {}

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
     * Always returns 0x1b (keccak-256).
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
    function uri(
        uint256 id
    ) public view override(ERC1155) returns (string memory) {
        return
            string.concat(
                LibIPFT.uri(contentCodecOf(id), multihashCodecOf(id), 32),
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
     * @param contentId     The token ID, also the keccak256 hash of `content`.
     * @param contentAuthor The to-become-token-author address.
     * @param content       The file containing an IPFT tag.
     * @param contentCodec  The content multicodec (e.g. `0x71` for dag-cbor).
     * @param ipftTagOffset The IPFT tag offset in bytes.
     */
    function _claim(
        uint256 contentId,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftTagOffset
    ) internal {
        require(
            msg.sender == contentAuthor ||
                isApprovedForAll(contentAuthor, msg.sender),
            "IPFT1155: unauthorized"
        );

        require(
            _contentAuthor[contentId] == address(0),
            "IPFT1155: already claimed"
        );

        LibIPFT.verifyTag(
            content,
            ipftTagOffset,
            address(this),
            contentAuthor
        );
        require(
            uint256(keccak256(content)) == contentId,
            "IPFT1155: hash mismatch"
        );

        _contentAuthor[contentId] = contentAuthor;
        _contentCodec[contentId] = contentCodec;

        emit Claim(contentId, contentAuthor, contentCodec, 0x1b);
    }

    /**
     * Mint a previously {_claim}ed IPFT1155 token.
     * Ensures the caller is authorized.
     */
    function _mint(
        address to,
        uint256 contentId,
        uint256 amount,
        bytes calldata data
    ) internal override(ERC1155) {
        require(
            _contentAuthor[contentId] == msg.sender ||
                isApprovedForAll(_contentAuthor[contentId], msg.sender),
            "IPFT1155: unauthorized"
        );

        super._mint(to, contentId, amount, data);
    }

    /**
     * Batch version of {_mint}.
     */
    function _mintBatch(
        address to,
        uint256[] calldata contentIds,
        uint256[] calldata amounts,
        bytes calldata data
    ) internal override(ERC1155) {
        for (uint256 i = 0; i < contentIds.length; i++) {
            require(
                _contentAuthor[contentIds[i]] == msg.sender ||
                    isApprovedForAll(
                        _contentAuthor[contentIds[i]],
                        msg.sender
                    ),
                "IPFT1155: unauthorized"
            );
        }

        super._mintBatch(to, contentIds, amounts, data);
    }
}
