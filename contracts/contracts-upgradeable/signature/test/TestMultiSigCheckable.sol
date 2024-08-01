// SPDX-License-Identifier: MIT
pragma solidity ~0.8.2;

import "../MultiSigCheckable.sol";
import "../../common/WithAdmin.sol";
import {UUPSUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 @notice
    Base class for contracts handling multisig transactions
      Rules:
      - First set up the master governance quorum (groupId 1). onlyOwner
	  - Owner can remove public or custom quorums, but cannot remove governance
	  quorums.
	  - Once master governance is setup, governance can add / remove any quorums
	  - All actions can only be submitted to chain by admin or owner
 */
contract TestMultiSigCheckable is Initializable, UUPSUpgradeable, WithAdmin, MultiSigCheckable {
	function initialize(address initialOwner, address initialAdmin) public initializer {
        __WithAdmin_init(initialOwner, initialAdmin);
        __EIP712_init("TEST_MULTISIG_CHECKABLE", "001.000");
        __UUPSUpgradeable_init();
    }

	function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}
}
