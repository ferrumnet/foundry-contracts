// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IGeneralTaxDistributor} from "../../contracts/taxing/IGeneralTaxDistributor.sol";
import {RandomHelper} from "../../contracts/math/RandomHelper.sol";
import {IBurnable} from "../../contracts/common/IBurnable.sol";
import {WithAdmin} from "../common/WithAdmin.sol";
import {IRewardPool} from "../../contracts/staking/interfaces/IRewardPool.sol";


/**
 * General tax distributor.
 */
contract GeneralTaxDistributorUpgradable is Initializable, UUPSUpgradeable, WithAdmin, IGeneralTaxDistributor {
    using SafeERC20 for IERC20;
    enum TargetType {
        NotSet,
        Burn,
        Address,
        DefaultRewardPool,
        CustomRewardPool
    }
    struct TokenInfo {
        uint248 bufferSize;
        uint8 tokenSpecificConfig; // 1 or 0
    }
    struct TargetConfig {
        uint8 len; // Max 27 weights
        uint32 totalW;
        uint216 weights;
    }
    struct TargetInfo {
        address tgt;
        TargetType tType;
    }

    /// custom:storage-location erc7201:ferrum.storage.generaltaxdistributor.001
    struct GeneralTaxDistributorStorageV001 {
        uint256 lowThresholdX1000;
        mapping(address => TokenInfo) tokenInfo;
        mapping(address => TargetConfig) tokenTargetConfigs;
        mapping(address => TargetInfo[]) tokenTargetInfos;
        mapping(address => mapping(address => address)) poolRoutingTable;
        TargetConfig globalTargetConfig;
        TargetInfo[] targetInfos;
        RandomHelper.RandomState roller;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.generaltaxdistributor.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant GeneralTaxDistributorStorageV001Location = 0xe769cc5cdbb3417d141adc0de95926e360f40b66a982600a1f4339ac63fe8100;

    function initialize(
        address initialOwner,
        address initialAdmin,
        uint256 _lowThresholdX1000
    ) public initializer {
        __WithAdmin_init(initialOwner, initialAdmin);
        __UUPSUpgradeable_init();
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        $.lowThresholdX1000 = _lowThresholdX1000;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    function _getGeneralTaxDistributorStorageV001() internal pure returns (GeneralTaxDistributorStorageV001 storage $) {
        assembly {
            $.slot := GeneralTaxDistributorStorageV001Location
        }
    }

    function globalTargetConfig() external view returns (TargetConfig memory) {
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        return $.globalTargetConfig;
    }

    function targetInfos(uint256 idx) external view returns (TargetInfo memory) {
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        return $.targetInfos[idx];
    }

    function turnRandomization(uint8 off) external onlyAdmin {
        require(off == 1 || off == 0, "GTD: invalid off");
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        $.roller.off = off;
    }

    /**
     * @dev Make sure to configure the token too
     */
    function setPoolRouting(
        address tokenAddress,
        address msgSender,
        address poolId
    ) external onlyAdmin {
        require(tokenAddress != address(0), "GTD: tokenAddress required");
        require(msgSender != address(0), "GTD: msgSender required");
        require(poolId != address(0), "GTD: poolId required");
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        $.poolRoutingTable[tokenAddress][msgSender] = poolId;
    }

    function configureToken(
        address tokenAddress,
        uint256 bufferSize,
        TargetInfo[] memory infos,
        uint216 weights
    ) external onlyAdmin {
        setTokenInfo(tokenAddress, bufferSize, 1);
        setTokenTargetInfos(tokenAddress, infos, weights);
    }

    function setTokenInfo(
        address tokenAdress,
        uint256 bufferSize,
        uint8 tokenSpecificConfig
    ) public onlyAdmin {
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        $.tokenInfo[tokenAdress] = TokenInfo({
            bufferSize: uint248(bufferSize),
            tokenSpecificConfig: tokenSpecificConfig
        });
    }

    function setTokenTargetInfos(
        address tokenAddress,
        TargetInfo[] memory infos,
        uint216 weights
    ) public onlyAdmin {
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        require(infos.length < 27, "GTD: infos too large");
        uint32 totalW = calcTotalW(uint8(infos.length), weights);
        TargetConfig memory conf = TargetConfig({
            len: uint8(infos.length),
            totalW: totalW,
            weights: weights
        });
        $.tokenTargetConfigs[tokenAddress] = conf;
        delete $.tokenTargetInfos[tokenAddress];
        for (uint256 i = 0; i < infos.length; i++) {
            $.tokenTargetInfos[tokenAddress].push(infos[i]);
        }
    }

    function setGlobalTargetInfos(TargetInfo[] memory infos, uint216 weights) external onlyAdmin {
        require(infos.length < 27, "GTD: infos too large");
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        uint32 totalW = calcTotalW(uint8(infos.length), weights);
        TargetConfig memory conf = TargetConfig({
            len: uint8(infos.length),
            totalW: totalW,
            weights: weights
        });
        $.globalTargetConfig = conf;
        delete $.targetInfos;
        for (uint256 i = 0; i < infos.length; i++) {
            $.targetInfos.push(infos[i]);
        }
    }

    function calcTotalW(uint8 len, uint256 weights) internal pure returns (uint32) {
        uint32 sum = 0;
        require(len < 256 / 8, "GTD: len too long");
        for (uint8 i = 0; i < len; i++) {
            uint8 mi = 8 * i;
            uint256 mask = 0xff << mi;
            uint256 poolRatio = mask & weights;
            poolRatio = poolRatio >> mi;
            require(poolRatio <= 256, "GTD: pool ratio too large");
            sum += uint32(poolRatio);
        }
        return sum;
    }

    function distributeTaxDirect(address token) external virtual returns (uint256) {
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        RandomHelper.RandomState memory _state = $.roller;
        return _distributeTax(token, tx.origin, token, _state);
    }

    function distributeTaxAvoidOrigin(
        address token,
        address origin
    ) external virtual override returns (uint256 amount) {
        return _distributeTaxRandomized(token, origin);
    }

    function distributeTax(address token) external override returns (uint256 amount) {
        return _distributeTaxRandomized(token, token);
    }

    function _distributeTaxRandomized(
        address token,
        address origin
    ) internal returns (uint256 amount) {
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        RandomHelper.RandomState memory _state = $.roller;
        if (_state.off == 1) {
            return _distributeTax(token, origin, tx.origin, _state);
        }
        bool _result = false;
        (_state, _result) = RandomHelper.rollingRandBool(
            _state,
            tx.origin,
            $.lowThresholdX1000
        );
        if (!_result) {
            return 0;
        } // Only randomly, once in a while, do the more expensive operation
        return _distributeTax(token, origin, tx.origin, _state);
    }

    function _distributeTax(
        address token,
        address origin,
        address origSender,
        RandomHelper.RandomState memory _roller
    ) internal returns (uint256) {
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        // Check balance, if less than buffer
        TokenInfo memory ti = $.tokenInfo[token];
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < ti.bufferSize) {
            return 0;
        }

        // Now lets distribute the balance
        (bytes26 newRoll, uint256 randX2p32) = RandomHelper.rollingRand(
            _roller.roll,
            origSender
        );
        _roller.roll = newRoll;
        $.roller = _roller;
        TargetConfig memory target = ti.tokenSpecificConfig != 0
            ? $.tokenTargetConfigs[token]
            : $.globalTargetConfig;
        if (target.len == 0) {
            ti.tokenSpecificConfig = 0;
            target = $.globalTargetConfig;
        }
        uint8 idx = rollAndIndex(randX2p32, target); // Use round robbin distribution
        return
            distributeToTarget(
                idx,
                ti.tokenSpecificConfig,
                token,
                origin,
                balance
            );
    }

    function rollAndIndex(
        uint256 randX2p32,
        TargetConfig memory _conf
    ) internal pure returns (uint8) {
        uint256 sum = 0;
        uint256 w = _conf.weights;
        randX2p32 = (randX2p32 * _conf.totalW) / (2**32);
        for (uint8 i = 0; i < _conf.len; i++) {
            uint8 mi = 8 * i;
            uint256 mask = 0xff << mi;
            uint256 poolRatio = mask & w;
            poolRatio = poolRatio >> mi;
            sum += poolRatio;
            if (sum >= randX2p32 && poolRatio != 0) {
                return i;
            }
        }
        return 0;
    }

    function distributeToTarget(
        uint8 idx,
        uint8 fromToken,
        address token,
        address origin,
        uint256 balance
    ) internal returns (uint256) {
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        TargetInfo memory tgt = fromToken != 0
            ? $.tokenTargetInfos[token][idx]
            : $.targetInfos[idx];
        if (tgt.tgt == origin) {
            return 0;
        }
        if (tgt.tType == TargetType.Burn) {
            IBurnable(token).burn(balance);
            return balance;
        }
        if (tgt.tType == TargetType.Address) {
            IERC20(token).safeTransfer(tgt.tgt, balance);
            return balance;
        }
        if (tgt.tType == TargetType.DefaultRewardPool) {
            IERC20(token).safeTransfer(tgt.tgt, balance);
            return IRewardPool(tgt.tgt).addMarginalReward(token);
        }
        if (tgt.tType == TargetType.CustomRewardPool) {
            IERC20(token).safeTransfer(tgt.tgt, balance);
            address stakeId = $.poolRoutingTable[token][msg.sender];
            return IRewardPool(tgt.tgt).addMarginalRewardToPool(stakeId, token);
        }
        return 0;
    }
}
