// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPFT1155.sol";

/**
 * The simplest IPFT1155 implementation.
 */
contract IPFT1155Impl is IPFT1155 {
    function claim(
        uint256 id,
        bytes calldata contentCodec,
        uint32 codec,
        uint32 tagOffset,
        address author
    ) public {
        _claim(id, contentCodec, codec, tagOffset, author);
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public {
        (IPFT1155)._mint(to, id, amount, data);
    }
}
