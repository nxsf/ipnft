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
    /// Emitted when an IPFT authorship is claimed.
    event Claim(
        address operator,
        address indexed author,
        uint256 id,
        uint32 codec
    );

    /// Get a token author nonce, used in {mint}.
    mapping(address => uint32) public authorNonce;

    /// Get a token content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) public codec;

    /// Get a token royalty, which is calculated as `royalty / 255`.
    mapping(uint256 => uint8) public royalty;

    constructor() ERC721("IPFT721", "IPFT") {}

    /// A struct to overcome the Solidity stack size limits.
    struct MintArgs {
        address author;
        address to;
        uint32 codec;
        uint8 royalty;
    }

    /**
     * Claim an IPFT(721) by proving its authorship (see {IPFT.verify}).
     * Upon success, a brand-new IPFT is minted to `to`.
     *
     * @notice The content shall have an ERC721 Metadata JSON file resolvable
     * at the "/metadata.json" path. See {tokenURI} for a metadata URI example.
     *
     * @param id           The token id, also the keccak256 hash of `content`.
     * @param content      The file containing an IPFT tag.
     * @param tagOffset    The IPFT tag offset in bytes.
     * @param args.author  The to-become-author address.
     * @param args.to      The address to mint the token to.
     * @param args.codec   The content codec (e.g. `0x71` for dag-cbor).
     * @param args.royalty The token royalty, calculated as `royalty / 255`.
     *
     * Emits {Claim}.
     */
    function mint(
        uint256 id,
        bytes calldata content,
        uint32 tagOffset,
        MintArgs calldata args
    ) public {
        require(
            msg.sender == args.author ||
                isApprovedForAll(args.author, msg.sender),
            "IPFT(721): unauthorized"
        );

        uint256 hash = uint256(
            IPFT.verify(
                content,
                tagOffset,
                address(this),
                args.author,
                authorNonce[args.author]++
            )
        );

        // Check the content hash against the token ID.
        require(hash == id, "IPFT(721): content hash mismatch");

        // Set codec.
        codec[id] = args.codec;

        // Set royalty.
        royalty[id] = args.royalty;

        // Mint the IPFT(721).
        _mint(args.to, id);

        emit Claim(msg.sender, args.author, id, args.codec);
    }

    /**
     * Batch version of {mint}. For a successive content,
     * the according {authorNonce} value naturally increments.
     */
    function mintBatch(
        uint256[] calldata tokenIds,
        bytes[] calldata contents,
        uint32[] calldata tagOffsets,
        MintArgs calldata args
    ) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            mint(tokenIds[i], contents[i], tagOffsets[i], args);
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, IERC165) returns (bool) {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * Return {IPFT.uri} + "/metadata.json".
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721) returns (string memory) {
        return string.concat(IPFT.uri(codec[tokenId]), "/metadata.json");
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
}
