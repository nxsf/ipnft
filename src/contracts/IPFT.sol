// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ToHexString.sol";

library IPFT {
    using ToHexString for uint32;

    /**
     * Prove an IPFT authorship by verifying that `content`
     * contains a nonced 56-byte IPFT tag at `offset`.
     *
     * At `offset` the following byte sequence is expected:
     *
     * magic    | version           | chain id        | contract address | author address
     * 4 bytes  | 4 bytes           | 8 bytes         | 20 bytes         | 20 bytes
     * `"ipft"` | `0x0165766d` [^1] | `block.chainid` | `contractAddr`   | `authorAddr`
     *
     * [^1]: ASCII string `\x{01}evm`.
     *
     * @return hash The keccak256 hash of `content`.
     */
    function verifyTag(
        bytes calldata content,
        uint32 tagOffset,
        address contractAddr,
        address authorAddr
    ) external view returns (bytes32 hash) {
        // Check the content length so that it may contain the tag.
        require(content.length >= tagOffset + 56, "IPFT: content too short");

        // Check the magic and version bytes.
        require(
            _bytesToUint64(content, tagOffset) == 0x697066740165766d,
            "IPFT: invalid magic bytes"
        );

        // Check the chain id.
        require(
            _bytesToUint64(content, tagOffset + 8) == uint64(block.chainid),
            "IPFT: invalid chain id"
        );

        // Check the tag contract address.
        require(
            _bytesToAddress(content, tagOffset + 16) == contractAddr,
            "IPFT: invalid contract address"
        );

        // Check the tag author.
        require(
            _bytesToAddress(content, tagOffset + 36) == authorAddr,
            "IPFT: invalid author address"
        );

        return keccak256(content);
    }

    /**
     * Return string `"http://f01[codec]1220{id}.ipfs"`,
     * where `[codec]` is replaced automaticly with the actual token codec.
     *
     * ```
     * http:// f 01 71 1b 20 {id} .ipfs
     *         │ │  │  │  │  └ Literal "{id}" string (to be hex-interoplated client-side)
     *         │ │  │  │  └ 32 bytes
     *         │ │  │  └ keccak256
     *         │ │  └ dag-cbor (for example)
     *         │ └ cidv1
     *         └ base16
     * ```
     */
    function uri(uint32 contentCodec) external pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "http://f01",
                    contentCodec.toHexString(),
                    "1b20{id}.ipfs"
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
}
