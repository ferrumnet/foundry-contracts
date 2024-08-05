// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../common/IFerrumDeployer.sol";
import "../signature/IDaoCallable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract DaoMintableErc20 is Ownable, ERC20Burnable, IDaoCallable {
	string public _name;
	string public _symbol;
	constructor() ERC20("", "") Ownable(msg.sender) {
		(_name, _symbol) = abi.decode(IFerrumDeployer(msg.sender).initData(), (string, string));
	}

    /**
     @notice The toke name
     */
	function name() public override view returns (string memory) {
		return _name;
	}

    /**
     @notice The toke symbol
     */
	function symbol() public override view returns (string memory) {
		return _symbol;
	}

    bytes32 constant TOKEN_MINT_METHOD =
        keccak256(
            "Mint(uint256 amount,address to)"
        );
    /**
     @notice Runs an action requested by DAO. Note that owner should be a DAO contract
     @param action The action
     @param parameters The action parameters
     */
    function daoAction(bytes32 action, bytes calldata parameters) external override onlyOwner {
        require(action == TOKEN_MINT_METHOD, "TD: bad action");
		(address to, uint256 supply) = abi.decode(parameters, (address, uint256));
		_mint(to, supply);
    }
}
