// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIPFT {
    /**
     * Get an IPFT author.
     * Zero address means that the author is undefined.
     */
    function authorOf(uint256 tokenId) external view returns (address);

    /**
     * Get an IPFT CID content multicodec[^1] value.
     *
     * [^1]: https://github.com/multiformats/multicodec
     */
    function multicodecOf(uint256 tokenId) external view returns (uint32);

    /**
     * Get an IPFT CID multihash multicodec[^1] value.
     *
     * [^1]: https://github.com/multiformats/multicodec
     */
    function multihashOf(uint256 tokenId) external view returns (uint32);

    /**
     * Get an IPFT CID multihash digest size value.
     */
    function digestSizeOf(uint256 tokenId) external view returns (uint32);
}
