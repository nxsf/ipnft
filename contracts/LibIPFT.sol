// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Interplanetary File Token (IPFT) library
 */
library LibIPFT {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * Prove an IPFT authorship by verifying that `content`
     * contains a nonced 56-byte IPFT tag at `offset`.
     *
     * At `offset` the following byte sequence is expected:
     *
     * magic    | version           | chain id        | contract address | author address
     * 4 bytes  | 4 bytes           | 8 bytes         | 20 bytes         | 20 bytes
     * `"ipft"` | `0x0165766d` [^1] | `block.chainid` | `contract_`      | `author`
     *
     * [^1]: ASCII string `\x{01}evm`.
     *
     * @param content   The file containing an IPFT tag.
     * @param tagOffset The IPFT tag offset in bytes.
     * @param contract_ The proving contract address.
     * @param author    The to-become-token-author address.
     */
    function verifyTag(
        bytes calldata content,
        uint32 tagOffset,
        address contract_,
        address author
    ) external view {
        // Check the content length so that it may contain the tag.
        require(
            content.length >= tagOffset + 56,
            "LibIPFT: content too short"
        );

        // Check the magic and version bytes.
        require(
            _bytesToUint64(content, tagOffset) == 0x697066740165766d,
            "LibIPFT: invalid magic bytes"
        );

        // Check the chain id.
        require(
            _bytesToUint64(content, tagOffset + 8) == uint64(block.chainid),
            "LibIPFT: invalid chain id"
        );

        // Check the tag contract address.
        require(
            _bytesToAddress(content, tagOffset + 16) == contract_,
            "LibIPFT: invalid contract address"
        );

        // Check the tag author.
        require(
            _bytesToAddress(content, tagOffset + 36) == author,
            "LibIPFT: invalid author address"
        );
    }

    /**
     * Return string `"http://f01[multicodec][multihash][digestSize]{id}.ipfs"`.
     *
     * ```
     * http:// f 01 71 1b 20 {id} .ipfs
     *         │ │  │  │  │  └ Literal "{id}" string (to be hex-interoplated client-side)[^1]
     *         │ │  │  │  └ [digestSize], e.g. 32
     *         │ │  │  └ [multihash], e.g. keccak-256
     *         │ │  └ [multicodec], e.g. dag-cbor
     *         │ └ cidv1
     *         └ base16
     * ```
     *
     * [^1]: In accordance with ERC721 & ERC1155 metadata standards.
     */
    function uri(
        uint32 multicodec,
        uint32 multihash,
        uint32 digestSize
    ) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "http://f01",
                    _toHexString(multicodec),
                    _toHexString(multihash),
                    _toHexString(digestSize),
                    "{id}.ipfs"
                )
            );
    }

    function _bytesToUint64(
        bytes memory source,
        uint32 offset
    ) private pure returns (uint64 parsedUint) {
        assembly {
            parsedUint := mload(add(source, add(8, offset)))
        }
    }

    function _bytesToAddress(
        bytes memory source,
        uint32 offset
    ) private pure returns (address parsedAddress) {
        assembly {
            parsedAddress := mload(add(source, add(20, offset)))
        }
    }

    function _toHexString(uint32 value) private pure returns (string memory) {
        if (value == 0) return "00";

        uint32 temp = value;
        uint8 length = 0;

        while (temp != 0) {
            length++;
            temp >>= 8;
        }

        bytes memory buffer = new bytes(2 * length);

        for (uint8 i = 2 * length; i > 0; i--) {
            buffer[i - 1] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }

        return string(buffer);
    }
}
