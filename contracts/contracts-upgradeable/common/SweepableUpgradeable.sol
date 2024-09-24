// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {WithAdminUpgradeable} from "./WithAdminUpgradeable.sol";


abstract contract SweepableUpgradeable is WithAdminUpgradeable {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:ferrum.storage.sweepable.001
    struct SweepableStorageV001 {
        bool sweepFrozen;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.sweepable.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant SweepableStorageV001Location = 0x501be003b95fbbd97d429e38784e33e3e5cdfaf3ddfa33121625540b893e7d00;

    function _getSweepableStorageV001() private pure returns (SweepableStorageV001 storage $) {
        assembly {
            $.slot := SweepableStorageV001Location
        }
    }

    function freezeSweep() external onlyAdmin {
        SweepableStorageV001 storage $ = _getSweepableStorageV001();
        $.sweepFrozen = true;
    }

    function sweepToken(address token, address to, uint256 amount) external onlyAdmin {
        SweepableStorageV001 storage $ = _getSweepableStorageV001();
        require(!$.sweepFrozen, "S: Sweep is frozen");
        IERC20(token).safeTransfer(to, amount);
    }
}
