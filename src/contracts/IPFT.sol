// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library IPFT {
    /**
     * Prove an IPFT ownership by proving that `content`
     * contains a nonced 80-byte IPFT tag at `offset`.
     *
     * At `offset` the following byte sequence is expected:
     *
     * version           | blockchain id   | contract address | prover address | nonce
     * 4 bytes           | 32 bytes        | 20 bytes         | 20 bytes       | 4 bytes
     * `0x65766d01` [^1] | `block.chainid` | `contractAddr`   | `prover`       | `nonce`
     *
     * [^1]: `0x65766d01` is the hex encoding of the ASCII string "evm\x01",
     * that is version 1 of the IPFT tag for the EVM.
     *
     * @return hash The keccak256 hash of `content`.
     */
    function prove(
        bytes calldata content,
        uint32 offset,
        address contractAddr,
        address prover,
        uint32 nonce
    ) internal view returns (bytes32 hash) {
        // Check the content length so that it may contain the tag.
        require(content.length >= offset + 80, "IPFT: content too short");

        // Check the tag version value.
        require(
            _bytesToUint32(content, offset) == 0x65766D01,
            "IPFT: invalid tag version"
        );

        // Check the tag blockchain id value.
        require(
            _bytesToUint256(content, offset + 4) == block.chainid,
            "IPFT: invalid blockchain id"
        );

        // Check the tag contract address.
        require(
            _bytesToAddress(content, offset + 36) == contractAddr,
            "IPFT: invalid contract address"
        );

        // Check the tag prover.
        require(
            _bytesToAddress(content, offset + 56) == prover,
            "IPFT: invalid prover"
        );

        // Check the tag nonce.
        require(
            _bytesToUint32(content, offset + 76) == nonce,
            "IPFT: invalid nonce"
        );

        return keccak256(content);
    }

    function _bytesToUint32(
        bytes memory source,
        uint32 offset
    ) internal pure returns (uint32 parsedUint) {
        assembly {
            parsedUint := mload(add(source, add(4, offset)))
        }
    }

    function _bytesToUint256(
        bytes memory source,
        uint32 offset
    ) internal pure returns (uint256 parsedUint) {
        assembly {
            parsedUint := mload(add(source, add(32, offset)))
        }
    }

    function _bytesToAddress(
        bytes memory source,
        uint32 offset
    ) internal pure returns (address parsedAddress) {
        assembly {
            parsedAddress := mload(add(source, add(20, offset)))
        }
    }
}
