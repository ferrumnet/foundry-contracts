// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IHasTaxDistributor.sol";

/**
 @notice A contract that uses tax distributer
 */
abstract contract HasTaxDistributor is Ownable, IHasTaxDistributor {
	address public override taxDistributor;

    /**
     @notice Sets the tax distributor. Only owner can call this function
     @param _taxDistributor The tax distributor
     */
	function setTaxDistributor(address _taxDistributor) external onlyOwner {
		taxDistributor = _taxDistributor;
	}
}