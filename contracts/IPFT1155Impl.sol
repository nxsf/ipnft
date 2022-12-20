// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPFT1155.sol";

/**
 * The simplest IPFT1155 implementation.
 */
contract IPFT1155Impl is IPFT1155 {
    function claim(
        uint256 contentId,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftTagOffset
    ) public {
        _claim(contentId, contentAuthor, content, contentCodec, ipftTagOffset);
    }

    function mint(
        address to,
        uint256 contentId,
        uint256 amount,
        bytes calldata data
    ) public {
        (IPFT1155)._mint(to, contentId, amount, data);
    }
}
