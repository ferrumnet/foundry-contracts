// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


/**
 * To freeze functionality. This is one way. Once you freeze there is no way back.
 */
abstract contract Freezable is OwnableUpgradeable {
    /// @custom:storage-location erc7201:ferrum.storage.freezable.001
    struct FreezeableStorageV001 {
        bool isFrozen;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.freezable.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant FreezableStorageV001Location = 0x9c47f24f7d551dfe423cbc7cb827a9fb704975fc1181b78265684facb23b5500;

    function _getFreezableStorageV001() private pure returns (FreezeableStorageV001 storage $) {
        assembly {
            $.slot := FreezableStorageV001Location
        }
    }

    /**
     * Freeze all the freezable functions.
     * They cannot be called any more.
     */
    function freeze() external onlyOwner() {
        FreezeableStorageV001 storage $ = _getFreezableStorageV001();
        $.isFrozen = true;
    }

    /**
     * @dev Throws if frozen
     * Only use on external functions.
     */
    modifier freezable() {
        FreezeableStorageV001 storage $ = _getFreezableStorageV001();
        require(!$.isFrozen, "Freezable: method is frozen");
        _;
    }
}