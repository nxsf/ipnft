// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "./IPFT.sol";

/**
 * @title Interplanetary File Token (1155)
 * @author Fancy Software <fancysoft.eth>
 *
 * IPFT(1155) is an ERC-1155-compliant IPFT.
 */
contract IPFT1155 is ERC1155, ERC1155Burnable, ERC1155Supply, IERC2981 {
    /// Get a token owner, if any.
    mapping(uint256 => address) public owner;

    /// Get an owner nonce, used in {mint}.
    mapping(address => uint32) public nonce;

    /// Get a token content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) public codec;

    /// Get a token royalty, which is calculated as `royalty / 255`.
    mapping(uint256 => uint8) public royalty;

    /// Once a token is finalized, it cannot be minted anymore.
    mapping(uint256 => bool) public isFinalized;

    constructor() ERC1155("") {}

    /**
     * Claim an IPFT ownership by proving that `content`
     * contains a valid IPFT tag at `offset`.
     * See {IPFT.prove} for more details.
     * Once claimed, the token may be {mint}ed.
     */
    function claim(
        uint256 id,
        bytes calldata content,
        uint32 offset,
        uint32 codec_,
        uint8 royalty_
    ) public {
        require(owner[id] == address(0), "IPFT1155: already claimed");

        bytes32 hash = IPFT.prove(
            content,
            offset,
            address(this),
            msg.sender,
            nonce[msg.sender]++
        );

        require(uint256(hash) == id, "IPFT(1155): hash mismatch");

        owner[id] = msg.sender;
        codec[id] = codec_;
        royalty[id] = royalty_;
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
            owner[id] == msg.sender || isApprovedForAll(owner[id], msg.sender),
            "IPFT(1155): unauthorized"
        );

        require(!isFinalized[id], "IPFT(1155): finalized");
        isFinalized[id] = finalize;

        _mint(to, id, amount, data);
    }

    /**
     * {claim}, then {mint} in a single transaction.
     */
    function claimMint(
        uint256 id,
        bytes calldata content,
        uint32 offset,
        uint32 codec_,
        uint8 royalty_,
        address to,
        uint256 amount,
        bool finalize,
        bytes calldata data
    ) public {
        claim(id, content, offset, codec_, royalty_);
        mint(to, id, amount, finalize, data);
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
                owner[ids[i]] == msg.sender ||
                    isApprovedForAll(owner[ids[i]], msg.sender),
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
            owner[tokenId],
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
