// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title AutomaticValidatorTransferApprovalUpgradeable
 * @author Limit Break, Inc. (modified for upgradeable patterns)
 * @notice Base contract mix-in that provides boilerplate code giving the contract owner the
 *         option to automatically approve a 721-C transfer validator implementation for transfers.
 */
abstract contract AutomaticValidatorTransferApprovalUpgradeable is Initializable {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Storage struct for upgradeable pattern (EIP-7201)
    struct AutoApprovalStorage {
        /// @dev If true, the collection's transfer validator is automatically approved to transfer holder's tokens.
        bool autoApproveTransfersFromValidator;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("rarible.storage.AutomaticValidatorTransferApproval")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AUTO_APPROVAL_STORAGE_SLOT = 
        0x8f8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e8e00;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Emitted when the automatic approval flag is modified by the creator.
    event AutomaticApprovalOfTransferValidatorSet(bool autoApproved);

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getAutoApprovalStorage() private pure returns (AutoApprovalStorage storage $) {
        assembly {
            $.slot := AUTO_APPROVAL_STORAGE_SLOT
        }
    }

    /**
     * @dev Initializes the auto-approval setting to true.
     */
    function __AutomaticValidatorTransferApproval_init() internal onlyInitializing {
        __AutomaticValidatorTransferApproval_init_unchained();
    }

    function __AutomaticValidatorTransferApproval_init_unchained() internal onlyInitializing {
        _setAutomaticApprovalOfTransfersFromValidator(true);
    }

    /**
     * @dev Internal function to set the automatic approval setting.
     */
    function _setAutomaticApprovalOfTransfersFromValidator(bool autoApprove) internal {
        _getAutoApprovalStorage().autoApproveTransfersFromValidator = autoApprove;
        emit AutomaticApprovalOfTransferValidatorSet(autoApprove);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether the transfer validator is auto-approved for all transfers
     */
    function autoApproveTransfersFromValidator() public view returns (bool) {
        return _getAutoApprovalStorage().autoApproveTransfersFromValidator;
    }

    /**
     * @notice Sets if the transfer validator is automatically approved as an operator for all token owners.
     * @dev Only callable by contract owner/admin (implement access control in derived contract)
     * @param autoApprove If true, the collection's transfer validator will be automatically approved to
     *                    transfer holder's tokens.
     */
    function setAutomaticApprovalOfTransfersFromValidator(bool autoApprove) external virtual;

    /**
     * @dev Reserved storage gap for future upgrades
     */
    uint256[49] private __gap;
}
