// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "./IPFT.sol";

/**
 * @title Interplanetary File Token (721)
 * @author Fancy Software <fancysoft.eth>
 *
 * An IPNFT(721) represents a digital copyright for an IPFS CID,
 * where a token ID is the 32-byte keccak256 digest part of it.
 *
 * To {mint} an IPFT(721) with a specific identifier, one must prove
 * the possession of the content containing a valid IPFT tag.
 */
contract IPFT721 is ERC721, IERC2981 {
    /// Get a minter nonce, used in {mint}.
    mapping(address => uint32) public nonce;

    /// Get a token content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) public codec;

    /// Get a token royalty, which is calculated as `royalty / 255`.
    mapping(uint256 => uint8) public royalty;

    constructor() ERC721("IPFT721", "IPFT") {}

    /**
     * Claim an IPFT(721) by proving its ownership (see {IPFT.prove}).
     * Upon success, a brand-new IPFT is minted to `to`.
     *
     * @notice The content shall have an ERC721 Metadata JSON file resolvable
     * at the "/metadata.json" path. See {tokenURI} for a metadata URI example.
     *
     * @param to        The address to mint the token to.
     * @param id        The token id, also the keccak256 hash of `content`.
     * @param content   The file containing an IPFT tag.
     * @param tagOffset The IPFT tag offset in bytes.
     * @param codec_    The content codec (e.g. `0x71` for dag-cbor).
     * @param royalty_  The token royalty, calculated as `royalty / 255`.
     */
    function mint(
        address to,
        uint256 id,
        bytes calldata content,
        uint32 tagOffset,
        uint32 codec_,
        uint8 royalty_
    ) public {
        uint256 hash = uint256(
            IPFT.prove(
                content,
                tagOffset,
                address(this),
                msg.sender,
                nonce[msg.sender]++
            )
        );

        // Check the content hash against the token ID.
        require(hash == id, "IPFT(721): content hash mismatch");

        // Set codec.
        codec[id] = codec_;

        // Set royalty.
        royalty[id] = royalty_;

        // Mint the IPFT(721).
        _mint(to, id);
    }

    /**
     * Batch version of {mint}. For a successive content,
     * the according {nonce} value naturally increments.
     */
    function mintBatch(
        address to,
        uint256[] calldata tokenIds,
        bytes[] calldata contents,
        uint32[] calldata tagOffsets,
        uint32 codec_,
        uint8 royalty_
    ) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            mint(
                to,
                tokenIds[i],
                contents[i],
                tagOffsets[i],
                codec_,
                royalty_
            );
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
     * Return string `"http://f01[codec]1220{id}.ipfs/metadata.json"`,
     * where `[codec]` is replaced automaticly with the actual token codec.
     *
     * ```
     * http:// f 01 71 1b 20 {id} .ipfs /metadata.json
     *         │ │  │  │  │  └ Literal "{id}" string (to be hex-interoplated client-side)
     *         │ │  │  │  └ 32 bytes
     *         │ │  │  └ keccak256
     *         │ │  └ dag-cbor (for example)
     *         │ └ cidv1
     *         └ base16
     * ```
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721) returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "http://f01",
                    _toHexString(codec[tokenId]),
                    "1b20{id}.ipfs/metadata.json"
                )
            );
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

    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    function _toHexString(uint32 value) internal pure returns (string memory) {
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
