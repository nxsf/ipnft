// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Interplanetary Non-fungible File Token (IPNFT) support library
 *
 * See {IIPNFT}.
 */
library LibIPNFT {
    bytes16 private constant _HEX = "0123456789abcdef";

    /**
     * Prove an IPNFT authorship by verifying that `content`
     * contains a 56-byte IPFT[^1] at `ipftOffset`.
     *
     * At `ipftOffset` the following byte sequence is expected:
     *
     * magic    | version           | chain id        | contract address  | author address
     * 4 bytes  | 4 bytes           | 8 bytes         | 20 bytes          | 20 bytes
     * `"ipft"` | `0x0165766d` [^2] | `block.chainid` | `contractAddress` | `contentAuthor`
     *
     * @param content         The file containing an IPFT.
     * @param ipftOffset      The IPFT offset in bytes.
     * @param contractAddress The proving contract address.
     * @param contentAuthor   The to-become-content-author address.
     *
     * [^1]: Interplanetary File Tag.
     * [^2]: ASCII string `\x{01}evm`.
     */
    function verifyIpft(
        bytes calldata content,
        uint32 ipftOffset,
        address contractAddress,
        address contentAuthor
    ) external view {
        // Check the content length so that it may contain the tag.
        require(
            content.length >= ipftOffset + 56,
            "LibIPNFT: content too short"
        );

        // Check the magic and version bytes.
        require(
            _bytesToUint64(content, ipftOffset) == 0x697066740165766d,
            "LibIPNFT: invalid magic bytes"
        );

        // Check the chain id.
        require(
            _bytesToUint64(content, ipftOffset + 8) == uint64(block.chainid),
            "LibIPNFT: invalid chain id"
        );

        // Check the tag contract address.
        require(
            _bytesToAddress(content, ipftOffset + 16) == contractAddress,
            "LibIPNFT: invalid contract address"
        );

        // Check the tag author.
        require(
            _bytesToAddress(content, ipftOffset + 36) == contentAuthor,
            "LibIPNFT: invalid author address"
        );
    }

    /**
     * Return string `"http://f01(multicodec)(multihash)(digestSize){id}.ipfs"`.
     *
     * ```
     * http:// f 01 71 1b 20 {id} .ipfs
     *         │ │  │  │  │  └ Literal "{id}" string (to be hex-interoplated client-side)[^1]
     *         │ │  │  │  └ `digestSize`, e.g. 32
     *         │ │  │  └ `multihash`, e.g. keccak-256
     *         │ │  └ `multicodec`, e.g. dag-cbor
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
            buffer[i - 1] = _HEX[value & 0xf];
            value >>= 4;
        }

        return string(buffer);
    }
}
