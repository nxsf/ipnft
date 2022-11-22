// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "./IPNFT721.sol";

/**
 * @title Interplanetary Non-Fungible Token: 1155
 * @author Fancy Software <fancysoft.eth>
 *
 * IPNFT1155 is an ERC-1155 {IPNFT721} derivative that can be (optionally)
 * redeemed by sending it back to this contract. A token may also be a part
 * of a {collection}, where a collection is a simple address.
 */
contract IPNFT1155 is
    ERC1155,
    ERC1155Burnable,
    ERC1155Supply,
    IERC1155Receiver,
    IERC2981
{
    IPNFT721 public ipnft721;

    /** A token may be a part of a collection defined by an address. */
    mapping(uint256 => address) public collection;

    /** Once a token is finalized, it cannot be minted anymore. */
    mapping(uint256 => bool) public isFinalized;

    /** If not zero, the token is considered {isRedeemable}. */
    mapping(uint256 => uint64) public expiredAt;

    constructor(IPNFT721 _ipnft) ERC1155("") {
        ipnft721 = _ipnft;
    }

    /**
     * Mint an IPNFT1155 token.
     *
     * @param collection_ A collection to make the token part of, if any.
     * The caller must be approved on behalf of the collection.
     * @param finalize To irreversibly disable further minting for this token.
     * @param expiredAt_ The timestamp the token ceases to be redeemable at.
     * May pass new value to update the expiration date.
     * If zero, the token is not considered redeemable.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        address collection_,
        bool finalize,
        uint64 expiredAt_,
        bytes calldata data
    ) public {
        require(
            ipnft721.isAuthorized(msg.sender, id),
            "IPNFT1155: IPNFT721-unauthorized"
        );

        require(to != address(this), "IPNFT1155: mint to this");

        require(!isFinalized[id], "IPNFT1155: finalized");
        isFinalized[id] = finalize;

        _updateCollection(id, collection_);
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
        address collection_,
        bool finalize,
        uint64 expiredAt_,
        bytes calldata data
    ) public {
        require(
            ipnft721.isAuthorizedBatch(msg.sender, ids),
            "IPNFT1155: IPNFT721-unauthorized"
        );

        require(to != address(this), "IPNFT1155: mint to this");

        for (uint256 i = 0; i < ids.length; i++) {
            require(!isFinalized[ids[i]], "IPNFT1155: finalized");
            isFinalized[ids[i]] = finalize;

            _updateCollection(ids[i], collection_);
            _updateExpiredAt(ids[i], expiredAt_);
        }

        _mintBatch(to, ids, amounts, data);
    }

    /**
     * Return true if {expiredAt} of the token is not zero.
     * Reverts if the token does not {exists}.
     */
    function isRedeemable(uint256 tokenId) public view returns (bool) {
        require(exists(tokenId), "IPNFT1155: does not exist");
        return expiredAt[tokenId] != 0;
    }

    /**
     * Return true if a redeemable token has expired.
     * Reverts if the token not {isRedeemable}.
     */
    function hasExpired(uint256 tokenId) public view returns (bool) {
        require(isRedeemable(tokenId), "IPNFT1155: not redeemable");
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
            "IPNFT1155: not from this contract"
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
            "IPNFT1155: not from this contract"
        );

        for (uint256 i = 0; i < ids.length; i++) {
            _ensureRedeemable(ids[i], values[i]);
        }

        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * Return {IPNFT721-royaltyInfo}.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override(IERC2981)
        returns (address receiver, uint256 royaltyAmount)
    {
        return ipnft721.royaltyInfo(tokenId, salePrice);
    }

    /**
     * Return {IPNFT721-tokenURI}.
     */
    function uri(uint256 id)
        public
        view
        override(ERC1155)
        returns (string memory)
    {
        return ipnft721.tokenURI(id);
    }

    function _updateCollection(uint256 id, address collection_) internal {
        if (collection_ != address(0)) {
            require(
                msg.sender == collection_ ||
                    isApprovedForAll(collection_, msg.sender),
                "IPNFT1155: collection unauthorized"
            );
        }

        require(
            collection[id] == address(0) || collection[id] == collection_,
            "IPNFT1155: collection mismatch"
        );

        collection[id] = collection_;
    }

    // TODO: Write tests.
    function _updateExpiredAt(uint256 id, uint64 expiredAt_) internal {
        if (exists(id)) {
            if (expiredAt[id] == 0) {
                require(expiredAt_ == 0, "IPNFT1155: not redeemable");
            } else {
                require(
                    expiredAt_ >= expiredAt[id],
                    "IPNFT1155: expiredAt is less than current"
                );
                require(expiredAt_ > block.timestamp, "IPNFT1155: expired");
            }
        } else {
            require(
                expiredAt_ == 0 || expiredAt_ > block.timestamp,
                "IPNFT1155: expired"
            );
        }

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
        require(isRedeemable(id), "IPNFT1155: not minted");
        require(!hasExpired(id), "IPNFT1155: expired");
        require(value > 0, "IPNFT1155: redeemable value is zero");
    }
}
