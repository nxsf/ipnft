// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IPNFT1155.sol";

/**
 * The simplest IPNFT1155 implementation.
 */
contract IPNFT1155Impl is IPNFT1155 {
    function claim(
        uint256 contentId,
        address contentAuthor,
        bytes calldata content,
        uint32 contentCodec,
        uint32 ipftOffset
    ) public {
        _claim(contentId, contentAuthor, content, contentCodec, ipftOffset);
    }

    function mint(
        address to,
        uint256 contentId,
        uint256 amount,
        bytes calldata data
    ) public {
        (IPNFT1155)._mint(to, contentId, amount, data);
    }
}
