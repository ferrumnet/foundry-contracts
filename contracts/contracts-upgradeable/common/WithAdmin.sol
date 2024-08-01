// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


abstract contract WithAdmin is Initializable, OwnableUpgradeable {
	/// @custom:storage-location erc7201:ferrum.storage.withadmin.001
    struct WithAdminStorageV001 {
        address admin;
    }

	// keccak256(abi.encode(uint256(keccak256("ferrum.storage.withadmin.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant WithAdminStorageV001Location = 0x9cc69353251ee3fe681ee5e74b127d3c581100030841b8c40ca6499da8df4f00;

	event AdminSet(address admin);

	function __WithAdmin_init(address initialOwner, address initialAdmin) internal onlyInitializing {
		__Ownable_init(initialOwner);
		__WithAdmin_init_unchained(initialAdmin);
	}

	function __WithAdmin_init_unchained(address initialAdmin) internal onlyInitializing {
		WithAdminStorageV001 storage $ = _getWithAdminStorageV001();
		$.admin = initialAdmin;
	}

	function _getWithAdminStorageV001() private pure returns (WithAdminStorageV001 storage $) {
        assembly {
            $.slot := WithAdminStorageV001Location
        }
    }

	function admin() public view returns (address) {
		WithAdminStorageV001 storage $ = _getWithAdminStorageV001();
		return $.admin;
	}

	function setAdmin(address _admin) external onlyOwner {
		WithAdminStorageV001 storage $ = _getWithAdminStorageV001();
		$.admin = _admin;
		emit AdminSet(_admin);
	}

	modifier onlyAdmin() {
		require(msg.sender == admin() || msg.sender == owner(), "WA: not admin");
		_;
	}
}
