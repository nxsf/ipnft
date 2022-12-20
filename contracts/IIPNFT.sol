// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Interplanetary Non-fungible Token (IPNFT) interface
 *
 * An IPNFT is an on-chain, digital proof of authorship
 * for an IPFS CID, tailored to existing NFT standards.
 *
 * In IPNFT, a token ID is also the 32-byte CID multihash digest.
 */
interface IIPNFT {
    /**
     * Emitted when an IPNFT is claimed.
     * Should be emitted prior to the first minting of the IPNFT.
     */
    event Claim(
        bytes32 indexed contentId, // Also the token ID, and multihash digest
        address indexed contentAuthor,
        uint32 contentCodec,
        uint32 multihashCodec
    );

    /**
     * Get an IPNFT content identifier, also the token ID and multihash digest.
     */
    function contentIdOf(uint256 tokenId) external view returns (bytes32);

    /**
     * Get an IPNFT content author.
     * Zero address means that the author is undefined.
     */
    function contentAuthorOf(uint256 tokenId) external view returns (address);

    /**
     * Get an IPNFT content multicodec[^1] value.
     *
     * [^1]: https://github.com/multiformats/multicodec
     */
    function contentCodecOf(uint256 tokenId) external view returns (uint32);

    /**
     * Get an IPNFT CID multihash multicodec[^1] value.
     * @notice The multihash digest MUST be 32 or less bytes long.
     *
     * [^1]: https://github.com/multiformats/multicodec
     */
    function multihashCodecOf(uint256 tokenId) external view returns (uint32);
}
