// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../common/IFerrumDeployer.sol";

contract MinimalErc20 is ERC20Burnable {
	string public _name;
	string public _symbol;
	constructor() ERC20("", "") {
		uint256 supply;
		address to;
		(_name, _symbol, to, supply) = abi.decode(IFerrumDeployer(msg.sender).initData(), (string, string, address, uint256));
		_mint(to, supply);
	}

	function name() public override view returns (string memory) {
		return _name;
	}

	function symbol() public override view returns (string memory) {
		return _symbol;
	}
}

contract MinimalErc20Deployer is IFerrumDeployer {
	bytes public override initData;
	event TokenDeployed(address token);

	function deploy(
		string memory name,
		string memory symbol,
		address to,
		uint256 totalSupply
	) external {
		(bytes32 salt, bytes memory data) = saltAndData(name, symbol, to, totalSupply, msg.sender);
		initData = data;
		address token = address(new MinimalErc20{ salt: salt }());
		delete initData;
		emit TokenDeployed(token);
	}

	function getsaltAndData(
		string memory name,
		string memory symbol,
		address to,
		uint256 totalSupply,
		address msgSender
	) external pure returns (bytes32 salt, bytes memory data) {
		(salt, data) = saltAndData(name, symbol, to, totalSupply, msgSender);
	}

	function saltAndData(
		string memory name,
		string memory symbol,
		address to,
		uint256 totalSupply,
		address msgSender
	) internal pure returns (bytes32 salt, bytes memory data) {
		salt = keccak256(abi.encode(msgSender, name, symbol));
		data = abi.encode(name, symbol, to, totalSupply);
	}
}