// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

import "./IPFT.sol";

/**
 * @title Interplanetary File Token (1155)
 * @author Onyx Software <nxsf.org>
 *
 * IPFT(1155) is an ERC-1155-compliant Interplanetary File Token contract.
 * Prior to {mint}ing, the token authorship must be {claim}ed.
 */
contract IPFT1155 is
    ERC1155,
    ERC1155Burnable,
    ERC1155Supply,
    IERC2981,
    Multicall
{
    /// Emitted when an IPFT authorship is claimed.
    event Claim(address operator, address indexed author, uint256 id);

    /// Get a token author, if any.
    mapping(uint256 => address) public author;

    /// Get a token content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) public codec;

    /// Get a token royalty, which is calculated as `royalty / 255`.
    mapping(uint256 => uint8) public royalty;

    /// Once a token is finalized, it cannot be minted anymore.
    mapping(uint256 => bool) public isFinalized;

    constructor() ERC1155("") {}

    /**
     * Claim an IPFT ownership by verifying that `content`
     * contains a valid IPFT tag at `offset`.
     * See {IPFT.verifyTag} for more details.
     * Once claimed, the token may be {mint}ed.
     * Emits {Claim}.
     *
     * @param id        The token ID, also the keccak256 hash of `content`.
     * @param author_   The to-become-token-author address.
     * @param content   The file containing an IPFT tag.
     * @param tagOffset The IPFT tag offset in bytes.
     * @param codec_    The content codec (e.g. `0x71` for dag-cbor).
     * @param royalty_  The token royalty, calculated as `royalty / 255`.
     */
    function claim(
        uint256 id,
        address author_,
        bytes calldata content,
        uint32 tagOffset,
        uint32 codec_,
        uint8 royalty_
    ) public {
        require(
            msg.sender == author_ || isApprovedForAll(author_, msg.sender),
            "IPFT(1155): unauthorized"
        );

        require(author[id] == address(0), "IPFT(1155): already claimed");

        bytes32 hash = IPFT.verifyTag(
            content,
            tagOffset,
            address(this),
            author_
        );

        require(uint256(hash) == id, "IPFT(1155): hash mismatch");

        author[id] = author_;
        codec[id] = codec_;
        royalty[id] = royalty_;

        emit Claim(msg.sender, author_, id);
    }

    /**
     * Mint a previously {claim}ed IPFT(1155) token.
     *
     * @param finalize To irreversibly disable further minting for this token.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bool finalize,
        bytes calldata data
    ) public {
        require(
            author[id] == msg.sender ||
                isApprovedForAll(author[id], msg.sender),
            "IPFT(1155): unauthorized"
        );

        require(!isFinalized[id], "IPFT(1155): finalized");
        isFinalized[id] = finalize;

        _mint(to, id, amount, data);
    }

    /**
     * Batch version of {mint}.
     */
    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bool finalize,
        bytes calldata data
    ) public {
        for (uint256 i = 0; i < ids.length; i++) {
            require(
                author[ids[i]] == msg.sender ||
                    isApprovedForAll(author[ids[i]], msg.sender),
                "IPFT(1155): unauthorized"
            );

            require(!isFinalized[ids[i]], "IPFT(1155): finalized");
            isFinalized[ids[i]] = finalize;
        }

        _mintBatch(to, ids, amounts, data);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, IERC165) returns (bool) {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
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
            author[tokenId],
            (salePrice * royalty[tokenId]) / type(uint8).max
        );
    }

    /**
     * Return {IPFT.uri} + "/metadata.json".
     */
    function uri(
        uint256 id
    ) public view override(ERC1155) returns (string memory) {
        return string.concat(IPFT.uri(codec[id]), "/metadata.json");
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
