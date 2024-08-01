// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDaoCallable} from "../../contracts/signature/IDaoCallable.sol";
import {MultiSigProofOfStake} from "./MultiSigProofOfStake.sol";
import {ISlashableStake} from "../../contracts/staking/interfaces/ISlashableStake.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


contract TokenDao is Initializable, UUPSUpgradeable, MultiSigProofOfStake {
    string public constant NAME = "TOKEN_DAO";
    string public constant VERSION = "001.000";
    uint64 public constant GOVERNANCE_GROUP_ID = 88;
    bytes32 constant DO_ACTION_METHOD_CALL = keccak256("DoAction(bytes32 action,bytes parameters,bytes32 salt,uint64 expiry)");
    bytes32 constant MINT_SIGNED_METHOD = keccak256("Mint(uint256 amount,address to,bytes32 salt,uint64 expiry)");
    bytes32 constant TOKEN_MINT_METHOD = keccak256("Mint(uint256 amount,address to)");
    bytes32 constant SLASH_STAKE_SIGNED_METHOD = keccak256("SlashStake(address staker,uint256 amount,bytes32 salt,uint64 expiry)");
    bytes32 constant UPGRADE_DAO = keccak256("UpgradeDao(address newDao,bytes32 salt,uint64 expiry)");

    /// custom:storage-location erc7201:ferrum.storage.tokendao.001
    struct TokenDaoStorageV001 {
        uint256 mintGovThreshold;
        uint256 slashStakeThreshold;
        address token;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.tokendao.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TokenDaoStorageV001Location = 0x68c3614664bff0f5da4f89220b0ffb0d779096c21de730beb70dae68e66f9e00;

    event TokenSet(address indexed token);
    event SlashStakeThresholdSet(uint256 stakeThresholdValue);
    event MintGovThresholdSet(uint256 govtThresholdValue);

    function _getTokenDaoStorageV001() private pure returns (TokenDaoStorageV001 storage $) {
        assembly {
            $.slot := TokenDaoStorageV001Location
        }
    }

    function initialize(address initialOwner, address initialAdmin) public initializer {
        __WithAdmin_init(initialOwner, initialAdmin);
        __EIP712_init(NAME, VERSION);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    function token() public view returns (address) {
        return _getTokenDaoStorageV001().token;
    }

    /**
     @notice Allow owner to change the token owner in case something goes wrong.
         After the trial period, this method can be frozen so it cannot be called
         anymore.
     @param newOwner The new owner
     */
    function changeTokenOwner(address newOwner) external onlyOwner freezable {
        OwnableUpgradeable(token()).transferOwnership(newOwner);
    }

    /**
     @notice Sets mint governance threshold. Setting this to zero effectively disables stake
         based governance.
         After the trial period, this method can be frozen so it cannot be called
         anymore.
     @param thr The threshold
     */
    function setMintGovThreshold(uint256 thr) external onlyOwner freezable {
        TokenDaoStorageV001 storage $ = _getTokenDaoStorageV001();
        $.mintGovThreshold = thr;
        emit MintGovThresholdSet(thr);
    }

    /**
     @notice Sets the slash stake threshold
         After the trial period, this method can be frozen so it cannot be called
         anymore.
     @param thr The threshold
     */
    function setSlashStakeThreshold(uint256 thr) external onlyOwner freezable {
        require(thr > 0, "TD: thr required");
        TokenDaoStorageV001 storage $ = _getTokenDaoStorageV001();
        $.slashStakeThreshold = thr;
        emit SlashStakeThresholdSet(thr);
    }

    /**
     @notice Sets the token. Only by owner
     @param _token The token
     */
    function setToken(address _token) external onlyOwner freezable {
        require(_token != address(0), "TD: _token requried");
        TokenDaoStorageV001 storage $ = _getTokenDaoStorageV001();
        $.token = _token;
        // event for keeping track of the new token
        emit TokenSet(_token);
    }

    /**
     @notice Calls an action on the token that is controlled by dao
     @param action The hash of the action message
     @param parameters The list of parameters
     @param salt The salt
     @param expiry The expiry timeout
     @param multiSignature The encodedd multisignature
     */
    function doAction(
        bytes32 action,
        bytes calldata parameters,
        bytes32 salt,
        uint64 expiry,
        bytes calldata multiSignature
    ) external onlyAdmin expiryRange(expiry) {
        TokenDaoStorageV001 storage $ = _getTokenDaoStorageV001();
        bytes32 message = keccak256(
            abi.encode(
                DO_ACTION_METHOD_CALL,
                action,
                parameters,
                salt,
                expiry
            )
        );
        verifyWithThreshold(
            message,
            salt,
            $.mintGovThreshold,
            GOVERNANCE_GROUP_ID,
            multiSignature
        );
        IDaoCallable($.token).daoAction(action, parameters);
    }

    /**
     @notice Mints more token. This should be signed by the governance, but
         only called by admin as a veto
     */
    function mint(
        uint256 amount,
        address to,
        bytes32 salt,
        uint64 expiry,
        bytes calldata multiSignature
    ) external onlyAdmin expiryRange(expiry) {
        TokenDaoStorageV001 storage $ = _getTokenDaoStorageV001();
        bytes32 message = keccak256(
            abi.encode(
                MINT_SIGNED_METHOD,
                amount,
                to,
                salt,
                expiry
            )
        );
        verifyWithThreshold(
            message,
            salt,
            $.mintGovThreshold,
            GOVERNANCE_GROUP_ID,
            multiSignature
        );
        IDaoCallable($.token).daoAction(TOKEN_MINT_METHOD, abi.encode(to, amount));
    }

    /**
     @notice Slashes someone stake
         only called by admin as a veto
     */
    function slashStake(
        address staker,
        uint256 amount,
        bytes32 salt,
        uint64 expiry,
        bytes calldata multiSignature
    ) external onlyAdmin expiryRange(expiry) {
        TokenDaoStorageV001 storage $ = _getTokenDaoStorageV001();
        MultiSigProofOfStakeStorageV001 storage $$ = _getMultiSigProofOfStakeStorageV001();

        bytes32 message = keccak256(
            abi.encode(
                SLASH_STAKE_SIGNED_METHOD,
                staker,
                amount,
                salt,
                expiry
            )
        );
        verifyWithThreshold(
            message,
            salt,
            $.slashStakeThreshold,
            GOVERNANCE_GROUP_ID,
            multiSignature
        );
        ISlashableStake($$.staking).slash($$.stakedToken, staker, amount);
    }

    /**
     @notice Updares the dao contract.
        only called by admin
     */
    function upgradeDao(
        address newDao,
        bytes32 salt,
        uint64 expiry,
        bytes calldata multiSignature
    ) external onlyAdmin expiryRange(expiry) {
        TokenDaoStorageV001 storage $ = _getTokenDaoStorageV001();
        bytes32 message = keccak256(
            abi.encode(
                UPGRADE_DAO,
                newDao,
                salt,
                expiry
            )
        );
        verifyWithThreshold(
            message,
            salt,
            $.mintGovThreshold,
            GOVERNANCE_GROUP_ID,
            multiSignature
        );
        OwnableUpgradeable($.token).transferOwnership(newDao);
    }
}
