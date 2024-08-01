// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SigCheckable} from "./SigCheckable.sol";
import {WithAdmin} from "../common/WithAdmin.sol";


abstract contract Allocatable is SigCheckable, WithAdmin {
    /// @custom:storage-location erc7201:ferrum.storage.allocatable.001
    struct AllocatableStorageV001 {
        mapping(address => bool) signers;
    }
    
    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.allocatable.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AllocatableStorageV001Location = 0x735797d21065a54184e3062a7791ec6eaf084dcdbb28f9712aa6cd84286f9100;

    function _getAllocatableStorageV001() private pure returns (AllocatableStorageV001 storage $) {
        assembly {
            $.slot := AllocatableStorageV001Location
        }
    }

    function addSigner(address _signer) external onlyOwner() {
        require(_signer != address(0), "Bad signer");
        AllocatableStorageV001 storage $ = _getAllocatableStorageV001();
        $.signers[_signer] = true;
    }

    function removeSigner(address _signer) external onlyOwner() {
        require(_signer != address(0), "Bad signer");
        AllocatableStorageV001 storage $ = _getAllocatableStorageV001();
        delete $.signers[_signer];
    }

    bytes32 constant AMOUNT_SIGNED_METHOD =
        keccak256("AmountSigned(bytes4 method, address token,address payee,address to,uint256 amount,uint64 expiry,bytes32 salt)");

    function amountSignedMessage(
			bytes4 method,
            address token,
            address payee,
            address to,
            uint256 amount,
			uint64 expiry,
            bytes32 salt
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(
          AMOUNT_SIGNED_METHOD,
		  method,
          token,
          payee,
		  to,
          amount,
		  expiry,
          salt));
    }

    function verifyAmountUnique(
			bytes4 method,
            address token,
            address payee,
            address to,
            uint256 amount,
            bytes32 salt,
			uint64 expiry,
            bytes memory signature
    ) internal {
		require(expiry == 0 || block.timestamp > expiry, "Allocatable: sig expired");
        bytes32 message = amountSignedMessage(method, token, payee, to, amount, expiry, salt);
        address _signer = signerUnique(message, signature);
        AllocatableStorageV001 storage $ = _getAllocatableStorageV001();
        require($.signers[_signer], "Allocatable: Invalid signer");
	}

    function verifyAmount(
			bytes4 method,
            address token,
            address payee,
            address to,
            uint256 amount,
            bytes32 salt,
			uint64 expiry,
            bytes memory signature
    ) internal view {
		require(expiry == 0 || block.timestamp > expiry, "Allocatable: sig expired");
        bytes32 message = amountSignedMessage(method, token, payee, to, amount, expiry, salt);
        (,address _signer) = signer(message, signature);
        AllocatableStorageV001 storage $ = _getAllocatableStorageV001();
        require($.signers[_signer], "Allocatable: Invalid signer");
	}
}
