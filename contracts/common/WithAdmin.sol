// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract WithAdmin is Ownable {
	address public admin;
	event AdminSet(address admin);

	function setAdmin(address _admin) external onlyOwner {
		admin = _admin;
		emit AdminSet(_admin);
	}

	modifier onlyAdmin() {
		require(msg.sender == admin || msg.sender == owner(), "WA: not admin");
		_;
	}
}