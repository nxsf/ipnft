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
 * the authorship of the content containing a valid IPFT tag.
 */
contract IPFT721 is ERC721, IERC2981 {
    /// Arguments for the {mint} function.
    struct MintArgs {
        /// The to-become IPFT {authorOf} address.
        address author;
        ///  The file containing an IPFT tag.
        bytes content;
        /// The IPFT tag offset in bytes.
        uint32 tagOffset;
        /// The content codec (e.g. `0x71` for dag-cbor).
        uint32 codec;
        /// The token royalty, calculated as `royalty / 255`.
        uint8 royalty;
    }

    /// Emitted when an IPFT authorship is {mint}ed.
    event Mint(
        address operator,
        address indexed author,
        uint256 id,
        uint32 codec
    );

    /// Get an IPFT author.
    mapping(uint256 => address) public authorOf;

    /// Get an IPFT content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) public codec;

    /// Get a token royalty, which is calculated as `royalty / 255`.
    mapping(uint256 => uint8) public royalty;

    constructor() ERC721("IPFT721", "IPFT") {}

    /**
     * Mint an IPFT(721) by proving its authorship (see {IPFT.verifyTag}).
     * Upon success, a brand-new IPFT(721) is minted to `to`.
     *
     * @notice The content shall have an ERC721 Metadata JSON file resolvable
     * at the "/metadata.json" path. See {tokenURI} for a metadata URI example.
     *
     * @param id The token id, also the keccak256 hash of `content`.
     * @param to The address to mint the token to.
     *
     * Emits {Mint}.
     */
    function mint(uint256 id, address to, MintArgs calldata args) public {
        require(
            msg.sender == args.author ||
                isApprovedForAll(args.author, msg.sender),
            "IPFT(721): unauthorized"
        );

        uint256 hash = uint256(
            IPFT.verifyTag(
                args.content,
                args.tagOffset,
                address(this),
                args.author
            )
        );

        // Check the content hash against the token ID.
        require(hash == id, "IPFT(721): content hash mismatch");

        // Set author.
        authorOf[id] = args.author;

        // Set codec.
        codec[id] = args.codec;

        // Set royalty.
        royalty[id] = args.royalty;

        // Mint the IPFT(721).
        _mint(to, id);

        emit Mint(msg.sender, args.author, id, args.codec);
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
