// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "./IPNFT.sol";

/**
 * @title Interplanetary Non-Fungible Token: Redeemable
 * @author Fancy Software <fancysoft.eth>
 *
 * IPNFTRedeemable is an {IPNFT} derivative that can be redeemed
 * by sending it back to this contract.
 */
contract IPNFTRedeemable is
    ERC1155,
    ERC1155Burnable,
    ERC1155Supply,
    IERC1155Receiver,
    IERC2981
{
    /// Used as an argument for {mintSuperBatch}.
    struct MintSuperBatchArgs {
        address to;
        uint8 royalty;
        bool finalize;
        uint64 expiredAt_;
    }

    IPNFT public ipnft;

    /** Once a token is finalized, it cannot be minted anymore. */
    mapping(uint256 => bool) public isFinalized;

    /** Once a token is expired, it cannot be redeemed anymore. */
    mapping(uint256 => uint64) public expiredAt;

    constructor(IPNFT _ipnft) ERC1155("") {
        ipnft = _ipnft;
    }

    /**
     * Mint an IPNFTRedeemable token.
     *
     * @param finalize   To irreversibly disable further minting for this token.
     * @param expiredAt_ The timestamp when the token ceases to be redeemable.
     * May pass new value to update the expiration date.
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
            ipnft.isAuthorized(msg.sender, id),
            "IPNFTRedeemable: IPNFT-unauthorized"
        );

        require(to != address(this), "IPNFTRedeemable: mint to this");

        require(!isFinalized[id], "IPNFTRedeemable: finalized");
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
        require(
            ipnft.isAuthorizedBatch(msg.sender, ids),
            "IPNFTRedeemable: IPNFT-unauthorized"
        );

        require(to != address(this), "IPNFTRedeemable: mint to this");

        for (uint256 i = 0; i < ids.length; i++) {
            require(!isFinalized[ids[i]], "IPNFTRedeemable: finalized");
            isFinalized[ids[i]] = finalize;

            _updateExpiredAt(ids[i], expiredAt_);
        }

        _mintBatch(to, ids, amounts, data);
    }

    /**
     * Return true if the token has been minted at least once.
     */
    function isMinted(uint256 tokenId) public view returns (bool) {
        return expiredAt[tokenId] != 0;
    }

    /**
     * Return true if the token has expired.
     * Reverts if the token not {isMinted}.
     */
    function hasExpired(uint256 tokenId) public view returns (bool) {
        require(isMinted(tokenId), "IPNFTRedeemable: not minted");
        return block.timestamp > expiredAt[tokenId];
    }

    /**
     * Redeem a single token by transferring it back to this contract.
     * The token must be {isMinted}.
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
            "IPNFTRedeemable: not from this contract"
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
            "IPNFTRedeemable: not from this contract"
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
     * Return {IPNFT-royaltyInfo}.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override(IERC2981)
        returns (address receiver, uint256 royaltyAmount)
    {
        return ipnft.royaltyInfo(tokenId, salePrice);
    }

    /**
     * Return {IPNFT-tokenURI}.
     */
    function uri(uint256 id)
        public
        view
        override(ERC1155)
        returns (string memory)
    {
        return ipnft.tokenURI(id);
    }

    function _updateExpiredAt(uint256 id, uint64 expiredAt_) internal {
        require(
            expiredAt[id] == 0 || block.timestamp < expiredAt[id],
            "IPNFTRedeemable: expired"
        );

        require(
            expiredAt_ > block.timestamp,
            "IPNFTRedeemable: expiredAt is less than current"
        );

        require(
            expiredAt_ >= expiredAt[id],
            "IPNFTRedeemable: expiredAt is less than previous"
        );

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
        require(isMinted(id), "IPNFTRedeemable: not minted");
        require(!hasExpired(id), "IPNFTRedeemable: expired");
        require(value > 0, "IPNFTRedeemable: value is zero");
    }
}
