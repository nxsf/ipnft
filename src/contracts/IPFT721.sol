// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./IPFT.sol";

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
contract IPFT721 is ERC721 {
    /// An IPFT author.
    mapping(uint256 => address) _author;

    /// An IPFT content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) _codec;

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    /**
     * Get an IPFT author.
     */
    function authorOf(uint256 tokenId) public view returns (address) {
        return _author[tokenId];
    }

    /**
     * Get an IPFT multicodec[^1] value.
     *
     * [^1]: https://github.com/multiformats/multicodec
     */
    function codecOf(uint256 tokenId) public view returns (uint32) {
        return _codec[tokenId];
    }

    /**
     * Return {IPFT.uri} + "/metadata.json".
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721) returns (string memory) {
        return string.concat(IPFT.uri(_codec[tokenId]), "/metadata.json");
    }

    /**
     * Mint an IPFT721 by proving its authorship (see {IPFT.verifyTag}).
     * Upon success, a brand-new IPFT721 is minted to `to`.
     *
     * @notice The content shall have an ERC721 Metadata JSON file resolvable
     * at the "/metadata.json" path. See {tokenURI} for a metadata URI example.
     *
     * @param to        The address to mint the token to.
     * @param id        The token id, also the keccak256 hash of `content`.
     * @param content   The file containing an IPFT tag.
     * @param codec     The content codec (e.g. `0x71` for dag-cbor).
     * @param tagOffset The IPFT tag offset in bytes.
     * @param author    The to-become-token-author address.
     */
    function _mint(
        address to,
        uint256 id,
        bytes calldata content,
        uint32 codec,
        uint32 tagOffset,
        address author
    ) internal {
        require(
            msg.sender == author || isApprovedForAll(author, msg.sender),
            "IPFT721: unauthorized"
        );

        uint256 hash = uint256(
            IPFT.verifyTag(content, tagOffset, address(this), author)
        );

        // Check the content hash against the token ID.
        require(hash == id, "IPFT721: content hash mismatch");

        // Set author.
        _author[id] = author;

        // Set codec.
        _codec[id] = codec;

        // Mint the IPFT721.
        _mint(to, id);
    }
}
