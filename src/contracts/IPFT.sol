// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ToHexString.sol";

library IPFT {
    using ToHexString for uint32;

    /**
     * Prove an IPFT authorship by verifying that `content`
     * contains a nonced 84-byte IPFT tag at `offset`.
     *
     * At `offset` the following byte sequence is expected:
     *
     * magic    | version | version  | chain id        | contract address | author address | nonce
     * 4 bytes  | 1 byte  | 3 bytes  | 32 bytes        | 20 bytes         | 20 bytes       | 4 bytes
     * `"ipft"` | `0x01`  | "evm"    | `block.chainid` | `contractAddr`   | `author`       | `nonce`
     *
     * @return hash The keccak256 hash of `content`.
     */
    function verify(
        bytes calldata content,
        uint32 tagOffset,
        address contractAddr,
        address author,
        uint32 nonce
    ) external view returns (bytes32 hash) {
        // Check the content length so that it may contain the tag.
        require(content.length >= tagOffset + 84, "IPFT: content too short");

        // Check the magic bytes.
        require(
            _bytesToUint32(content, tagOffset) == 0x69706674,
            "IPFT: invalid magic bytes"
        );

        // Check the tag version value.
        require(
            _bytesToUint32(content, tagOffset + 4) == 0x0165766d,
            "IPFT: invalid tag version"
        );

        // Check the tag blockchain id value.
        require(
            _bytesToUint256(content, tagOffset + 8) == block.chainid,
            "IPFT: invalid blockchain id"
        );

        // Check the tag contract address.
        require(
            _bytesToAddress(content, tagOffset + 40) == contractAddr,
            "IPFT: invalid contract address"
        );

        // Check the tag author.
        require(
            _bytesToAddress(content, tagOffset + 60) == author,
            "IPFT: invalid author"
        );

        // Check the tag nonce.
        require(
            _bytesToUint32(content, tagOffset + 80) == nonce,
            "IPFT: invalid nonce"
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

    function _bytesToUint32(
        bytes memory source,
        uint32 offset
    ) private pure returns (uint32 parsedUint) {
        assembly {
            parsedUint := mload(add(source, add(4, offset)))
        }
    }

    function _bytesToUint256(
        bytes memory source,
        uint32 offset
    ) private pure returns (uint256 parsedUint) {
        assembly {
            parsedUint := mload(add(source, add(32, offset)))
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
