// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";


/**
 @dev Make sure to define method signatures
 */
abstract contract SigCheckable is EIP712Upgradeable {
    /// @custom:storage-location erc7201:ferrum.storage.sigcheckable.001
    struct SigCheckableStorageV001 {
        mapping(bytes32=>bool) usedHashes;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.sigcheckable.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SigCheckableStorageV001Location = 0x875b9d674fc0e3554b3420ae0d71b7c4c8f47f6e82b2671ec0332385e8017d00;

    function _getSigCheckableStorageV001() private pure returns (SigCheckableStorageV001 storage $) {
        assembly {
            $.slot := SigCheckableStorageV001Location
        }
    }
    
    function signerUnique(
        bytes32 message,
        bytes memory signature
    ) internal returns (address _signer) {
        SigCheckableStorageV001 storage $ = _getSigCheckableStorageV001();

        bytes32 digest;
        (digest, _signer) = signer(message, signature);
        require(!$.usedHashes[digest], "Message already used");
        $.usedHashes[digest] = true;
    }

    /*
        @dev example message;

        bytes32 constant METHOD_SIG =
            keccak256("WithdrawSigned(address token,address payee,uint256 amount,bytes32 salt)");
        bytes32 message = keccak256(abi.encode(
          METHOD_SIG,
          token,
          payee,
          amount,
          salt
    */
    function signer(
        bytes32 message,
        bytes memory signature
    ) internal view returns (bytes32 digest, address _signer) {
        digest = _hashTypedDataV4(message);
        _signer = ECDSA.recover(digest, signature);
    }
}
