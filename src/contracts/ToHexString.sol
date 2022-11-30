// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ToHexString {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    function toHexString(uint32 value) internal pure returns (string memory) {
        if (value == 0) return "00";

        uint32 temp = value;
        uint8 length = 0;

        while (temp != 0) {
            length++;
            temp >>= 8;
        }

        bytes memory buffer = new bytes(2 * length);

        for (uint8 i = 2 * length; i > 0; i--) {
            buffer[i - 1] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }

        return string(buffer);
    }
}
