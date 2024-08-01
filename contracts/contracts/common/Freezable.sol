// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * To freeze functionality. This is one way. Once you freeze there is no way back.
 */
abstract contract Freezable is Ownable {
    bool isFrozen;

    /**
     * Freeze all the freezable functions.
     * They cannot be called any more.
     */
    function freeze() external onlyOwner() {
        isFrozen = true;
    }

    /**
     * @dev Throws if frozen
     * Only use on external functions.
     */
    modifier freezable() {
        require(!isFrozen, "Freezable: method is frozen");
        _;
    }
}