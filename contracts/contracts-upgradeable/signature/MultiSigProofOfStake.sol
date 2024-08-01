// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IStakeInfo} from "../../contracts/staking/interfaces/IStakeInfo.sol";
import {Freezable} from "../common/Freezable.sol";
import {MultiSigCheckable} from "./MultiSigCheckable.sol";


abstract contract MultiSigProofOfStake is Freezable, MultiSigCheckable {
    /// custom:storage-location erc7201:ferrum.storage.multisigproofofstake.001
    struct MultiSigProofOfStakeStorageV001 {
        address staking;
        address stakedToken;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.multisigproofofstake.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MultiSigProofOfStakeStorageV001Location = 0x58ae65de03eeb1bbd6533ac656349a2ed5a7fb475536f542d8ff1ca3ddc53300;

    function _getMultiSigProofOfStakeStorageV001() internal pure returns (MultiSigProofOfStakeStorageV001 storage $) {
        assembly {
            $.slot := MultiSigProofOfStakeStorageV001Location
        }
    }

    /**
     @notice Sets the stake contract and its token. Only admin can call this function
     @param stakingContract The staking contract
     @param _stakedToken The staked token
     */
    function setStake(address stakingContract, address _stakedToken) external onlyAdmin freezable {
        require(stakingContract != address(0), "MSPS: stakingContract required");
        require(_stakedToken != address(0), "MSPS: _stakedToken required");

        MultiSigProofOfStakeStorageV001 storage $ = _getMultiSigProofOfStakeStorageV001();
        $.staking = stakingContract;
        $.stakedToken = _stakedToken;
    }

    /**
     @notice Verifies a signed message considering staking threshold
     @param message The msg digest
     @param salt The salt
     @param thresholdX100 The staked threshold between 0 and 100
     @param expectedGroupId The group ID signing the request
     @param multiSignature The multisig signatures
     */
    function verifyWithThreshold(
        bytes32 message,
        bytes32 salt,
        uint256 thresholdX100,
        uint64 expectedGroupId,
        bytes memory multiSignature
    ) internal {
        MultiSigProofOfStakeStorageV001 storage $ = _getMultiSigProofOfStakeStorageV001();
        MultiSigCheckableStorageV001 storage $$ = _getMultiSigCheckableStorageV001();

        require(multiSignature.length != 0, "MSPS: multiSignature required");
        bytes32 digest = _hashTypedDataV4(message);
        bool result;
        address[] memory signers;
        (result, signers) = tryVerifyDigestWithAddress(digest, expectedGroupId, multiSignature);
        require(result, "MSPS: Invalid signature");
        require(!$$.usedHashes[salt], "MSPS: Message digest already used");
        $$.usedHashes[salt] = true;

        address _staking = $.staking;
        if (_staking != address(0)) {
            // Once all signatures are verified, make sure we have the staked ratio covered
            address token = $.stakedToken;
            uint256 stakedTotal = IStakeInfo(_staking).stakedBalance(token);
            uint256 signersStake;
            for(uint256 i=0; i < signers.length; i++) {
                signersStake = signersStake + IStakeInfo(_staking).stakeOf(token, signers[i]);
            }
            require( signersStake * 100 / stakedTotal >= thresholdX100, "MSPS: Staked signatures don't meet the sthreshold");
        }
    }
}