// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GeneralTaxDistributorUpgradable} from "./GeneralTaxDistributorUpgradeable.sol";


/**
 * General tax distributor.
 */
contract GeneralTaxDistributorDiscreteUpgradeable is GeneralTaxDistributorUpgradable {

    function distributeTaxDirect(address token
    ) external override returns (uint256) {
        return _distributeTaxNonRandom(token, token);
    }

    function distributeTaxAvoidOrigin(address token, address origin)
        external
        override
        returns (uint256 amount)
    {
        return _distributeTaxNonRandom(token, origin);
    }

    function _distributeTaxNonRandom(
        address token,
        address origin
    ) internal returns (uint256) {
        // Check balance, if less than buffer
        GeneralTaxDistributorStorageV001 storage $ = _getGeneralTaxDistributorStorageV001();
        TokenInfo memory ti = $.tokenInfo[token];
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance < ti.bufferSize) {
            return 0;
        }

        TargetConfig memory target = ti.tokenSpecificConfig != 0
            ? $.tokenTargetConfigs[token]
            : $.globalTargetConfig;
        if (target.len == 0) {
            ti.tokenSpecificConfig = 0;
            target = $.globalTargetConfig;
        }

        uint256 remaining = balance;
        uint256 w = target.weights;
        for (uint8 i = 0; i < target.len; i++) {
            uint256 amount;
            { // scope to avoid stack too deep
                uint8 mi = 8 * i;
                uint256 mask = 0xff << mi;
                uint256 poolRatio = mask & w;
                poolRatio = poolRatio >> mi;
                amount = poolRatio * balance / target.totalW;
            }

            if (remaining > amount) {
                remaining -= amount;
            } else {
                amount = remaining;
            }
            if (amount != 0) {
                return distributeToTarget(
                        i,
                        ti.tokenSpecificConfig,
                        token,
                        origin,
                        amount
                    );
            }
        }
        return 0;
    }
}