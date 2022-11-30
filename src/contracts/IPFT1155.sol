// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "./IPFT721.sol";

/**
 * @title Interplanetary File Token (1155)
 * @author Fancy Software <fancysoft.eth>
 *
 * IPFT(1155) is an ERC-1155-compliant IPFT derivative relying on IPFT(721)
 * to determine minting rights and auxiliary information.
 */
contract IPFT1155 is ERC1155, ERC1155Burnable, ERC1155Supply, IERC2981 {
    IPFT721 public ipft721;

    /** Once a token is finalized, it cannot be minted anymore. */
    mapping(uint256 => bool) public isFinalized;

    constructor(IPFT721 _ipft721) ERC1155("") {
        ipft721 = _ipft721;
    }

    /**
     * Mint an IPFT(1155) token.
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
            ipft721.isAuthorized(msg.sender, id),
            "IPFT(1155): IPFT(721)-unauthorized"
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
        require(
            ipft721.isAuthorizedBatch(msg.sender, ids),
            "IPFT(1155): IPFT(721)-unauthorized"
        );

        for (uint256 i = 0; i < ids.length; i++) {
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
