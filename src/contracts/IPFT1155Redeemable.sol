// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "./IPFT721.sol";

/**
 * @title Interplanetary File Token (1155): Redeemable
 * @author Fancy Software <fancysoft.eth>
 *
 * IPFT(1155)Redeemable is an ERC-1155-compliant IPFT derivative
 * relying on IPFT(721) to determine minting rights and auxiliary information.
 * An IPFT(1155)Redeemable can be redeemed by sending back to this contract.
 */
contract IPFT1155Redeemable is
    ERC1155,
    ERC1155Burnable,
    ERC1155Supply,
    IERC1155Receiver,
    IERC2981
{
    IPFT721 public ipft721;

    /** Once a token is finalized, it cannot be minted anymore. */
    mapping(uint256 => bool) public isFinalized;

    /** If not zero, the token is considered {isRedeemable}. */
    mapping(uint256 => uint64) public expiredAt;

    constructor(IPFT721 _ipft721) ERC1155("") {
        ipft721 = _ipft721;
    }

    /**
     * Mint an IPFT(1155)Redeemable token.
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
            ipft721.isAuthorized(msg.sender, id),
            "IPFT(1155)Redeemable: IPFT(721)-unauthorized"
        );

        require(to != address(this), "IPFT(1155)Redeemable: mint to this");

        require(!isFinalized[id], "IPFT(1155)Redeemable: finalized");
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
            ipft721.isAuthorizedBatch(msg.sender, ids),
            "IPFT(1155)Redeemable: IPFT(721)-unauthorized"
        );

        require(to != address(this), "IPFT(1155)Redeemable: mint to this");

        for (uint256 i = 0; i < ids.length; i++) {
            require(!isFinalized[ids[i]], "IPFT(1155)Redeemable: finalized");
            isFinalized[ids[i]] = finalize;

            _updateExpiredAt(ids[i], expiredAt_);
        }

        _mintBatch(to, ids, amounts, data);
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
            "IPFT(1155)Redeemable: not from this contract"
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
            "IPFT(1155)Redeemable: not from this contract"
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
     * Return {IPFT-royaltyInfo}.
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
        return ipft721.royaltyInfo(tokenId, salePrice);
    }

    /**
     * Return {IPFT-tokenURI}.
     */
    function uri(
        uint256 id
    ) public view override(ERC1155) returns (string memory) {
        return ipft721.tokenURI(id);
    }

    // TODO: Write tests.
    function _updateExpiredAt(uint256 id, uint64 expiredAt_) internal {
        if (exists(id)) {
            require(
                expiredAt_ >= expiredAt[id],
                "IPFT(1155)Redeemable: expiredAt is less than current"
            );
        }

        require(expiredAt_ > block.timestamp, "IPFT(1155)Redeemable: expired");

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
        require(value > 0, "IPFT(1155)Redeemable: redeemable value is zero");
        require(!hasExpired(id), "IPFT(1155)Redeemable: expired");
    }
}
