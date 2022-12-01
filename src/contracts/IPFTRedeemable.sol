// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "./IPFT.sol";

/**
 * @title Interplanetary File Token (Redeemable)
 * @author Fancy Software <fancysoft.eth>
 *
 * IPFT(Redeemable) is an ERC-1155-compliant IPFT
 * which can be redeemed by sending back to this contract.
 */
contract IPFTRedeemable is
    ERC1155,
    ERC1155Burnable,
    ERC1155Supply,
    IERC1155Receiver,
    IERC2981
{
    /// Arguments for the {claim} function.
    struct ClaimArgs {
        /// The to-become-token-author address.
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

    /// Emitted when an IPFT authorship is {claim}ed.
    event Claim(
        address operator,
        address indexed author,
        uint256 id,
        uint32 codec
    );

    /// Get a token author, if any.
    mapping(uint256 => address) public author;

    /// Get a token author nonce, used in {claim}.
    mapping(address => uint32) public authorNonce;

    /// Get a token content codec (e.g. 0x71 for dag-cbor).
    mapping(uint256 => uint32) public codec;

    /// Get a token royalty, which is calculated as `royalty / 255`.
    mapping(uint256 => uint8) public royalty;

    /// Once a token is finalized, it cannot be minted anymore.
    mapping(uint256 => bool) public isFinalized;

    /// Get a redeemable token expiration timestamp.
    mapping(uint256 => uint64) public expiredAt;

    constructor() ERC1155("") {}

    /**
     * Claim an IPFT ownership by verifying that `content`
     * contains a valid IPFT tag at `tagOffset`.
     * See {IPFT.verify} for more details.
     * Once claimed, the token may be {mint}ed.
     * Emits {Claim}.
     */
    function claim(uint256 id, ClaimArgs calldata args) public {
        require(
            msg.sender == args.author ||
                isApprovedForAll(args.author, msg.sender),
            "IPFT(1155): unauthorized"
        );

        require(author[id] == address(0), "IPFT(Redeemable): already claimed");

        bytes32 hash = IPFT.verify(
            args.content,
            args.tagOffset,
            address(this),
            args.author,
            authorNonce[args.author]++
        );

        require(uint256(hash) == id, "IPFT(Redeemable): hash mismatch");

        author[id] = args.author;
        codec[id] = args.codec;
        royalty[id] = args.royalty;

        emit Claim(msg.sender, args.author, id, args.codec);
    }

    /**
     * Mint a previously {claim}ed IPFT(Redeemable) token.
     *
     * @param finalize   To irreversibly disable further minting for this token.
     * @param expiredAt_ The timestamp the token ceases to be redeemable at.
     * Must be greater than the current block timestamp.
     * May pass new value to update the expiration date.
     * The new value must be greater than or equal to the current one.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bool finalize,
        uint64 expiredAt_,
        bytes calldata data
    ) public {
        require(
            author[id] == msg.sender ||
                isApprovedForAll(author[id], msg.sender),
            "IPFT(Redeemable): unauthorized"
        );

        require(to != address(this), "IPFT(Redeemable): mint to this");

        require(!isFinalized[id], "IPFT(Redeemable): finalized");
        isFinalized[id] = finalize;

        _updateExpiredAt(id, expiredAt_);
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
        uint64 expiredAt_,
        bytes calldata data
    ) public {
        require(to != address(this), "IPFT(Redeemable): mint to this");

        for (uint256 i = 0; i < ids.length; i++) {
            require(
                author[ids[i]] == msg.sender ||
                    isApprovedForAll(author[ids[i]], msg.sender),
                "IPFT(Redeemable): unauthorized"
            );

            require(!isFinalized[ids[i]], "IPFT(Redeemable): finalized");
            isFinalized[ids[i]] = finalize;

            _updateExpiredAt(ids[i], expiredAt_);
        }

        _mintBatch(to, ids, amounts, data);
    }

    /**
     * {claim}, then {mint} in one transaction.
     */
    function claimMint(
        uint256 id,
        ClaimArgs calldata claimArgs,
        address to,
        uint256 amount,
        bool finalize,
        uint64 expiredAt_,
        bytes calldata data
    ) public {
        claim(id, claimArgs);
        mint(to, id, amount, finalize, expiredAt_, data);
    }

    /**
     * Return true if a token has expired.
     */
    function hasExpired(uint256 tokenId) public view returns (bool) {
        return block.timestamp > expiredAt[tokenId];
    }

    /**
     * Redeem a single token by transferring it back to this contract.
     * The token must be {isRedeemable} and not {hasExpired}.
     * @notice The total supply of the token would stay the same.
     */
    function onERC1155Received(
        address,
        address,
        uint256 id,
        uint256 value,
        bytes calldata
    ) external view override(IERC1155Receiver) returns (bytes4) {
        require(
            msg.sender == address(this),
            "IPFT(Redeemable): not from this contract"
        );

        _ensureRedeemable(id, value);

        return IERC1155Receiver.onERC1155Received.selector;
    }

    /**
     * Redeem a batch of tokens by transferring it back to this contract.
     * See {onERC1155Received}.
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata
    ) external view override(IERC1155Receiver) returns (bytes4) {
        require(
            msg.sender == address(this),
            "IPFT(Redeemable): not from this contract"
        );

        for (uint256 i = 0; i < ids.length; i++) {
            _ensureRedeemable(ids[i], values[i]);
        }

        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
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

    // TODO: Write tests.
    function _updateExpiredAt(uint256 id, uint64 expiredAt_) internal {
        if (exists(id)) {
            require(
                expiredAt_ >= expiredAt[id],
                "IPFT(Redeemable): expiredAt is less than current"
            );
        }

        require(expiredAt_ > block.timestamp, "IPFT(Redeemable): expired");

        expiredAt[id] = expiredAt_;
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

    function _ensureRedeemable(uint256 id, uint256 value) internal view {
        require(value > 0, "IPFT(Redeemable): redeemable value is zero");
        require(!hasExpired(id), "IPFT(Redeemable): expired");
    }
}
