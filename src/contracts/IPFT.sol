// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title Interplanetary File Token
 * @author Fancy Software <fancysoft.eth>
 *
 * An IPFT represents a digital copyright for a DAG-CBOR IPFS CID,
 * where a token ID is the 32-byte SHA-2-256 digest part of it.
 *
 * To {mint} an IPFT with a specific identifier, one must prove
 * the possession of the content containing a valid IPFT tag.
 */
contract IPFT is ERC721, IERC2981 {
    /// Get an address minter nonce, used in {mint}.
    mapping(address => uint32) public minterNonce;

    /// Get a token royalty, which is calculated as `royalty / 255`.
    mapping(uint256 => uint8) public royalty;

    constructor() ERC721("IPFT", "IPFT") {}

    /**
     * Claim an IPFT ownership by proving that the root DAG-CBOR file
     * contains a nonced 80-byte IPFT tag at `tagOffset`.
     *
     * First, the SHA-256 hash of the `content` is computed and compared to `id`.
     *
     * Then, at `tagOffset` the following byte sequence is expected:
     *
     * version           | blockchain id   | contract address | minter address | minter nonce
     * 4 bytes           | 32 bytes        | 20 bytes         | 20 bytes       | 4 bytes
     * `0x65766d01` [^1] | `block.chainid` | `address(this)`  | `minter`       | `minterNonce[minter]`
     *
     * [^1]: `0x65766d01` is the hex encoding of the ASCII string "evm\x01",
     * that is version 1 of the IPFT tag for the EVM.
     *
     * Upon successfull checks, a brand-new IPFT is minted to `to`.
     *
     * @notice The CBOR file shall contain a link to an ERC721 Metadata JSON file
     * at the root key "metadata.json", so that it is accessible via "/metadata.json".
     * See {tokenURI} for the metadata URI example.
     *
     * @param minter    The address of the token minter (must be caller or approved).
     * @param id        The token id, also the SHA-2-256 hash of `content`.
     * @param content   The root DAG-CBOR file containing the IPFT tag.
     * @param tagOffset The IPFT tag offset in bytes.
     * @param royalty_  The token royalty, calculated as `royalty / 255`.
     */
    function mint(
        address minter,
        uint256 id,
        bytes calldata content,
        uint32 tagOffset,
        uint8 royalty_
    ) public {
        require(
            msg.sender == minter || isApprovedForAll(minter, msg.sender),
            "IPFT: not allowed"
        );

        // Check the content hash against the token ID.
        require(uint256(sha256(content)) == id, "IPFT: content hash mismatch");

        // Check the content length so that it may contain the tag.
        require(content.length >= tagOffset + 80, "IPFT: content too short");

        // Check the tag version value.
        require(
            _bytesToUint32(content, tagOffset) == 0x65766D01,
            "IPFT: invalid tag version"
        );

        // Check the tag blockchain id value.
        require(
            _bytesToUint256(content, tagOffset + 4) == block.chainid,
            "IPFT: invalid blockchain id"
        );

        // Check the tag contract address.
        require(
            _bytesToAddress(content, tagOffset + 36) == address(this),
            "IPFT: invalid contract address"
        );

        // Check the tag minter address.
        require(
            _bytesToAddress(content, tagOffset + 56) == minter,
            "IPFT: invalid minter address"
        );

        // Check the tag minter nonce.
        require(
            _bytesToUint32(content, tagOffset + 76) == minterNonce[minter],
            "IPFT: invalid minter nonce"
        );

        // Increment the minter nonce.
        minterNonce[minter] += 1;

        // Set royalty.
        royalty[id] = royalty_;

        // Mint the IPFT.
        _mint(minter, id);
    }

    /**
     * Batch version of {mint}. For a successive CBOR file,
     * the according {minterNonce} value increments.
     */
    function mintBatch(
        address minter,
        uint256[] calldata tokenIds,
        bytes[] calldata contents,
        uint32[] calldata tagOffsets,
        uint8 royalty_
    ) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            mint(minter, tokenIds[i], contents[i], tagOffsets[i], royalty_);
        }
    }

    /**
     * Check if `operator` is either the owner of the `tokenId`,
     * {getApproved} or {isApprovedForAll} on behalf of the owner.
     */
    function isAuthorized(
        address operator,
        uint256 tokenId
    ) public view returns (bool) {
        return
            operator == ownerOf(tokenId) ||
            operator == getApproved(tokenId) ||
            isApprovedForAll(ownerOf(tokenId), operator);
    }

    /**
     * Batch version of {isAuthorized}, checking authorization for *all* `tokenIds`.
     */
    function isAuthorizedBatch(
        address operator,
        uint256[] memory tokenIds
    ) public view returns (bool) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!(isAuthorized(operator, tokenIds[i]))) return false;
        }

        return true;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, IERC165) returns (bool) {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * Always return string `"http://f01711220{id}.ipfs/metadata.json"`.
     *
     * ```
     * http:// f 01 71 12 20 {id} .ipfs /metadata.json
     *         │ │  │  │  │  └ Literal "{id}" string (to be hex-interoplated client-side)
     *         │ │  │  │  └ 32 bytes
     *         │ │  │  └ sha-2-256
     *         │ │  └ dag-cbor
     *         │ └ cidv1
     *         └ base16
     * ```
     */
    function tokenURI(
        uint256
    ) public pure override(ERC721) returns (string memory) {
        return "http://f01711220{id}.ipfs/metadata.json";
    }

    /**
     * See {IERC2981-royaltyInfo}.
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    )
        external
        view
        override(IERC2981)
        returns (address receiver, uint256 royaltyAmount)
    {
        return (
            ownerOf(tokenId),
            (salePrice * royalty[tokenId]) / type(uint8).max
        );
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
