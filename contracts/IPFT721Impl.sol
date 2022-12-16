// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPFT721.sol";

/**
 * The simplest IPFT721 implementation.
 */
contract IPFT721Impl is IPFT721 {
    constructor() IPFT721("IPFT721", "IPFT") {}

    function mint(
        address to,
        uint256 id,
        bytes calldata content,
        uint32 contentCodec,
        uint32 tagOffset,
        address author
    ) public {
        _mint(to, id, content, contentCodec, tagOffset, author);
    }
}
