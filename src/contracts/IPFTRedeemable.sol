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

    /// Get a redeemable token expiration timestamp.
    mapping(uint256 => uint64) public expiredAt;

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
        require(owner[id] == address(0), "IPFT(Redeemable): already claimed");
        bytes32 hash = IPFT.prove(
            content,
            offset,
            address(this),
            msg.sender,
            nonce[msg.sender]++
        );
        require(uint256(hash) == id, "IPFT(Redeemable): hash mismatch");
        owner[id] = msg.sender;
        codec[id] = codec_;
        royalty[id] = royalty_;
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
            owner[id] == msg.sender || isApprovedForAll(owner[id], msg.sender),
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
                owner[ids[i]] == msg.sender ||
                    isApprovedForAll(owner[ids[i]], msg.sender),
                "IPFT(Redeemable): unauthorized"
            );
            require(!isFinalized[ids[i]], "IPFT(Redeemable): finalized");
            isFinalized[ids[i]] = finalize;
            _updateExpiredAt(ids[i], expiredAt_);
        }
        _mintBatch(to, ids, amounts, data);
    }

    /// A struct to overcome the Solidity stack size limits.
    struct ClaimMintArgs {
        uint256 id;
        uint32 offset;
        uint32 codec_;
        uint8 royalty_;
        address to;
        uint256 amount;
        bool finalize;
        uint64 expiredAt_;
    }

    /**
     * {claim}, then {mint} in one transaction.
     */
    function claimMint(
        ClaimMintArgs calldata args,
        bytes calldata content,
        bytes calldata data
    ) public {
        claim(args.id, content, args.offset, args.codec_, args.royalty_);
        mint(
            args.to,
            args.id,
            args.amount,
            args.finalize,
            args.expiredAt_,
            data
        );
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
