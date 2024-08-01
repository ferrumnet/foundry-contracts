// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../common/IFerrumDeployer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DummyToken is ERC20Burnable {
	constructor() ERC20("Dummy", "DMT") {
		(address to) = abi.decode(IFerrumDeployer(msg.sender).initData(), (address));
		_mint(to, 100000 * 10 ** 18);
	}
}

contract DummyTokenOwnable is DummyToken, Ownable {
    constructor()Ownable(msg.sender){}
}
