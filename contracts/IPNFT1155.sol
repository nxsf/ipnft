// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "./LibIPNFT.sol";
import "./IIPNFT.sol";

/**
 * @title Interplanetary File Token (1155)
 * @author Onyx Software Foundation <nxsf.org>
 *
 * An IPNFT1155 is a ERC1155-compliant digital copyright for an IPFS CID,
 * where a token ID is the 32-byte keccak256 digest part of it.
 *
 * To {_claim} an IPNFT1155 with a specific identifier, one must prove
 * the authorship of the content containing a valid IP(N)FT tag.
 *
 * Only after claiming an IPNFT1155, it can be {_mint}ed.
 */
contract IPNFT1155 is ERC1155, IIPNFT {
    /// Multihash keccak-256 codec.
    uint32 private constant _KECCAK256 = 0x1b;

    /// An IPNFT content author.
    mapping(uint256 => address) private _contentAuthor;

    /// An IPNFT content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) private _contentCodec;

    constructor() ERC1155("") {}

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
     * Always returns 0x1b (keccak-256).
     * See {IIPNFT.multihashCodecOf}.
     */
    function multihashCodecOf(
        uint256
    ) public pure override(IIPNFT) returns (uint32) {
        return _KECCAK256;
    }

    /**
     * Return {IPNFT.uri} + "/metadata.json".
     */
    function uri(
        uint256 id
    ) public view override(ERC1155) returns (string memory) {
        return
            string.concat(
                LibIPNFT.uri(contentCodecOf(id), multihashCodecOf(id), 32),
                "/metadata.json"
            );
    }

    /**
     * Claim an IPNFT1155 authorship by proving that `content`
     * contains a valid IPFT[^1] (see {LibIPNFT.verifyIpft}).
     *
     * Once claimed, the token may be {_mint}ed.
     *
     * @notice The content shall have an ERC1155 Metadata JSON file resolvable
     * at the "/metadata.json" path. See {uri} for a metadata URI example.
     *
     * @param contentId     The token ID, also the keccak256 hash of `content`.
     * @param contentAuthor The to-become-token-author address.
     * @param content       The file containing a valid IPFT.
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
    ) internal {
        require(
            msg.sender == contentAuthor ||
                isApprovedForAll(contentAuthor, msg.sender),
            "IPNFT1155: unauthorized"
        );

        require(
            _contentAuthor[contentId] == address(0),
            "IPNFT1155: already claimed"
        );

        LibIPNFT.verifyIpft(content, ipftOffset, address(this), contentAuthor);
        require(
            uint256(keccak256(content)) == contentId,
            "IPNFT1155: hash mismatch"
        );

        _contentAuthor[contentId] = contentAuthor;
        _contentCodec[contentId] = contentCodec;

        emit Claim(
            contentIdOf(contentId),
            contentAuthor,
            contentCodec,
            multihashCodecOf(contentId)
        );
    }

    /**
     * Mint a previously {_claim}ed IPNFT1155 token.
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
            "IPNFT1155: unauthorized"
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
                "IPNFT1155: unauthorized"
            );
        }

        super._mintBatch(to, contentIds, amounts, data);
    }
}
