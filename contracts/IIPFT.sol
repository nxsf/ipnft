// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIPFT {
    /**
     * Emitted when an IPFT is claimed.
     * Should be emitted prior to the first minting of the IPFT.
     */
    event Claim(
        address indexed contentAuthor,
        uint32 contentCodec,
        uint32 multihashCodec,
        uint32 multihashDigestSize,
        bytes multihashDigest
    );

    /**
     * Get an IPFT content author.
     * Zero address means that the author is undefined.
     */
    function contentAuthorOf(uint256 tokenId) external view returns (address);

    /**
     * Get an IPFT CID content multicodec[^1] value.
     *
     * [^1]: https://github.com/multiformats/multicodec
     */
    function contentCodecOf(uint256 tokenId) external view returns (uint32);

    /**
     * Get an IPFT CID multihash multicodec[^1] value.
     *
     * [^1]: https://github.com/multiformats/multicodec
     */
    function multihashCodecOf(uint256 tokenId) external view returns (uint32);

    /**
     * Get an IPFT CID multihash digest size value.
     */
    function multihashDigestSizeOf(
        uint256 tokenId
    ) external view returns (uint32);

    /**
     * Get an IPFT CID multihash digest value.
     */
    function multihashDigestOf(
        uint256 tokenId
    ) external view returns (bytes memory);
}
