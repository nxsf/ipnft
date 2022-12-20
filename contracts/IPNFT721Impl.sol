// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPNFT721.sol";

/**
 * The simplest IPNFT721 implementation.
 */
contract IPNFT721Impl is IPNFT721 {
    constructor() IPNFT721("IPNFT721", "IPNFT") {}

    function mint(
        address to,
        uint256 contentId,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftOffset
    ) public {
        _mint(to, contentId, contentAuthor, content, contentCodec, ipftOffset);
    }
}
