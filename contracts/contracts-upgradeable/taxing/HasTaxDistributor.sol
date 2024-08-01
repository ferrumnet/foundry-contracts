// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../contracts/taxing/IHasTaxDistributor.sol";

/**
 @notice A contract that uses tax distributer
 */
abstract contract HasTaxDistributor is OwnableUpgradeable, IHasTaxDistributor {
    /// common:storage-location erc7201:ferrum.storage.hastaxdistributor.001
    struct HasTaxDistributorStorageV001 {
        address taxDistributor;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.hastaxdistributor.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant HasTaxDistributorStorageV001Location = 0xe5ada7069980504f8a28a1aeb34930d77cea84c88e2cebde3e203b095fde4200;

    function _getHasTaxDistributorStorageV001() private pure returns (HasTaxDistributorStorageV001 storage $) {
        assembly {
            $.slot := HasTaxDistributorStorageV001Location
        }
    }

    /**
     @notice Sets the tax distributor. Only owner can call this function
     @param _taxDistributor The tax distributor
     */
	function setTaxDistributor(address _taxDistributor) external onlyOwner {
        HasTaxDistributorStorageV001 storage $ = _getHasTaxDistributorStorageV001();
		$.taxDistributor = _taxDistributor;
	}
}
