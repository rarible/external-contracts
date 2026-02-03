// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./TransferValidationUpgradeable.sol";
import "../interface/ICreatorToken.sol";
import "../interface/ITransferValidator.sol";

/**
 * @title CreatorTokenBaseUpgradeable
 * @author Limit Break, Inc. (modified for upgradeable patterns)
 * @notice CreatorTokenBaseUpgradeable is an abstract contract that provides basic functionality for managing token 
 * transfer policies through an implementation of ICreatorTokenTransferValidator/ICreatorTokenTransferValidatorV2/ICreatorTokenTransferValidatorV3. 
 * This contract is intended to be used as a base for creator-specific token contracts, enabling customizable transfer 
 * restrictions and security policies.
 *
 * <h4>Features:</h4>
 * <ul>Ownable: This contract can have an owner who can set and update the transfer validator.</ul>
 * <ul>TransferValidation: Implements the basic token transfer validation interface.</ul>
 *
 * <h4>Benefits:</h4>
 * <ul>Provides a flexible and modular way to implement custom token transfer restrictions and security policies.</ul>
 * <ul>Allows creators to enforce policies such as account and codehash blacklists, whitelists, and graylists.</ul>
 * <ul>Can be easily integrated into other token contracts as a base contract.</ul>
 *
 * <h4>Compatibility:</h4>
 * <ul>Backward and Forward Compatible - V1/V2/V3 Creator Token Base will work with V1/V2/V3 Transfer Validators.</ul>
 */
abstract contract CreatorTokenBaseUpgradeable is TransferValidationUpgradeable, ICreatorToken {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev The default transfer validator that will be used if no transfer validator has been set by the creator.
    address public constant DEFAULT_TRANSFER_VALIDATOR = address(0x721C008fdff27BF06E7E123956E2Fe03B63342e3);

    /// @dev Token type constant for ERC721
    uint16 public constant TOKEN_TYPE_ERC721 = 721;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Storage struct for upgradeable pattern (EIP-7201)
    struct CreatorTokenStorage {
        /// @dev Used to determine if the default transfer validator is applied.
        /// @dev Set to true when the creator sets a transfer validator address.
        bool isValidatorInitialized;
        /// @dev Address of the transfer validator to apply to transactions.
        address transferValidator;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("rarible.storage.CreatorTokenBase")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CREATOR_TOKEN_STORAGE_SLOT = 
        0x7f9e3e3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b3b00;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Thrown when setting a transfer validator address that has no deployed code.
    error CreatorTokenBase__InvalidTransferValidatorContract();

    /// @dev Thrown when trying to set security policy without a transfer validator.
    error CreatorTokenBase__SetTransferValidatorFirst();

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getCreatorTokenStorage() private pure returns (CreatorTokenStorage storage $) {
        assembly {
            $.slot := CREATOR_TOKEN_STORAGE_SLOT
        }
    }

    /**
     * @dev Initializes the creator token base. Should be called in the contract's initializer.
     */
    function __CreatorTokenBase_init() internal onlyInitializing {
        __CreatorTokenBase_init_unchained();
    }

    function __CreatorTokenBase_init_unchained() internal onlyInitializing {
        _emitDefaultTransferValidator();
        _registerTokenType(DEFAULT_TRANSFER_VALIDATOR);
    }

    /**
     * @dev Used during contract initialization to emit the `TransferValidatorUpdated` event 
     *      signaling the validator for the contract is the default transfer validator.
     */
    function _emitDefaultTransferValidator() internal {
        emit TransferValidatorUpdated(address(0), DEFAULT_TRANSFER_VALIDATOR);
    }

    /**
     * @dev Registers the token type with the transfer validator
     */
    function _registerTokenType(address validator) internal {
        if (validator != address(0)) {
            uint256 validatorCodeSize;
            assembly {
                validatorCodeSize := extcodesize(validator)
            }
            if (validatorCodeSize > 0) {
                try ITransferValidatorSetTokenType(validator).setTokenTypeOfCollection(address(this), _tokenType()) {
                } catch {}
            }
        }
    }

    /**
     * @dev Pre-validates a token transfer, reverting if the transfer is not allowed by this token's security policy.
     *      Inheriting contracts are responsible for overriding the _beforeTokenTransfer function, or its equivalent
     *      and calling _validateBeforeTransfer so that checks can be properly applied during token transfers.
     *
     * @dev Be aware that if the msg.sender is the transfer validator, the transfer is automatically permitted, as the
     *      transfer validator is expected to pre-validate the transfer.
     *
     * @dev Throws when the transfer doesn't comply with the collection's transfer policy, if the transferValidator is
     *      set to a non-zero address.
     *
     * @param caller  The address of the caller.
     * @param from    The address of the sender.
     * @param to      The address of the receiver.
     * @param tokenId The token id being transferred.
     */
    function _preValidateTransfer(
        address caller, 
        address from, 
        address to, 
        uint256 tokenId, 
        uint256 /*value*/
    ) internal virtual override {
        address validator = getTransferValidator();

        if (validator != address(0)) {
            if (msg.sender == validator) {
                return;
            }

            ITransferValidator(validator).validateTransfer(caller, from, to, tokenId);
        }
    }

    /**
     * @dev Pre-validates a token transfer, reverting if the transfer is not allowed by this token's security policy.
     *      Inheriting contracts are responsible for overriding the _beforeTokenTransfer function, or its equivalent
     *      and calling _validateBeforeTransfer so that checks can be properly applied during token transfers.
     *
     * @dev Be aware that if the msg.sender is the transfer validator, the transfer is automatically permitted, as the
     *      transfer validator is expected to pre-validate the transfer.
     * 
     * @dev Used for ERC20 and ERC1155 token transfers which have an amount value to validate in the transfer validator.
     * @dev The `tokenId` for ERC20 tokens should be set to `0`.
     *
     * @dev Throws when the transfer doesn't comply with the collection's transfer policy, if the transferValidator is
     *      set to a non-zero address.
     *
     * @param caller  The address of the caller.
     * @param from    The address of the sender.
     * @param to      The address of the receiver.
     * @param tokenId The token id being transferred.
     * @param amount  The amount of token being transferred.
     */
    function _preValidateTransfer(
        address caller, 
        address from, 
        address to, 
        uint256 tokenId, 
        uint256 amount,
        uint256 /*value*/
    ) internal virtual override {
        address validator = getTransferValidator();

        if (validator != address(0)) {
            if (msg.sender == validator) {
                return;
            }

            ITransferValidator(validator).validateTransfer(caller, from, to, tokenId, amount);
        }
    }

    /**
     * @dev Internal function to set the transfer validator.
     *
     * @dev Throws when provided validator contract is not the zero address and does not have code.
     *
     * @dev <h4>Postconditions:</h4>
     *      1. The transferValidator address is updated.
     *      2. The `TransferValidatorUpdated` event is emitted.
     *
     * @param transferValidator_ The address of the transfer validator contract.
     */
    function _setTransferValidator(address transferValidator_) internal {
        CreatorTokenStorage storage $ = _getCreatorTokenStorage();

        bool isValidTransferValidator = transferValidator_.code.length > 0;

        if (transferValidator_ != address(0) && !isValidTransferValidator) {
            revert CreatorTokenBase__InvalidTransferValidatorContract();
        }

        emit TransferValidatorUpdated(getTransferValidator(), transferValidator_);

        $.isValidatorInitialized = true;
        $.transferValidator = transferValidator_;

        _registerTokenType(transferValidator_);
    }

    /**
     * @dev Returns the token type. Override in derived contracts for different token types.
     */
    function _tokenType() internal pure virtual returns (uint16) {
        return TOKEN_TYPE_ERC721;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the transfer validator contract address for this token contract.
     */
    function getTransferValidator() public view override returns (address validator) {
        CreatorTokenStorage storage $ = _getCreatorTokenStorage();
        validator = $.transferValidator;

        if (validator == address(0)) {
            if (!$.isValidatorInitialized) {
                validator = DEFAULT_TRANSFER_VALIDATOR;
            }
        }
    }

    /**
     * @notice Sets the transfer validator for the token contract.
     * @dev Only callable by contract owner/admin (implement access control in derived contract)
     * @param validator The address of the new transfer validator
     */
    function setTransferValidator(address validator) external virtual override;

    /**
     * @notice Returns the function selector for the transfer validator's validation function
     *         to be called for transaction simulation.
     * @return functionSignature The function selector
     * @return isViewFunction Whether the function is a view function
     */
    function getTransferValidationFunction() external pure override returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    /*//////////////////////////////////////////////////////////////
                        SECURITY POLICY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the collection to use the default security policy on the transfer validator
     * @dev Only callable by contract owner/admin (implement access control in derived contract)
     */
    function setToDefaultSecurityPolicy() external virtual;

    /**
     * @notice Sets a custom security level for the collection
     * @dev Only callable by contract owner/admin (implement access control in derived contract)
     * @param level The security level to set
     */
    function setToCustomSecurityPolicy(uint8 level) external virtual;

    /**
     * @notice Sets a custom security policy with a specific list ID (whitelist/blacklist)
     * @dev Only callable by contract owner/admin (implement access control in derived contract)
     * @param level The security level to set
     * @param listId The list ID to apply
     */
    function setToCustomSecurityPolicyWithList(uint8 level, uint120 listId) external virtual;

    /**
     * @notice Gets the current security policy for this collection
     * @return transferSecurityLevel The current security level
     * @return listId The current list ID
     */
    function getSecurityPolicy() external view returns (uint8 transferSecurityLevel, uint120 listId) {
        address validator = getTransferValidator();
        if (validator != address(0)) {
            try ICreatorTokenTransferValidator(validator).getCollectionSecurityPolicy(address(this)) 
                returns (uint8 level, uint120 id) 
            {
                return (level, id);
            } catch {}
        }
        return (0, 0);
    }

    /**
     * @dev Internal function to set the security level on the transfer validator
     */
    function _setTransferSecurityLevel(uint8 level) internal {
        address validator = getTransferValidator();
        if (validator == address(0)) {
            revert CreatorTokenBase__SetTransferValidatorFirst();
        }
        ICreatorTokenTransferValidator(validator).setTransferSecurityLevelOfCollection(address(this), level);
    }

    /**
     * @dev Internal function to apply a list to the collection
     */
    function _applyListToCollection(uint120 listId) internal {
        address validator = getTransferValidator();
        if (validator == address(0)) {
            revert CreatorTokenBase__SetTransferValidatorFirst();
        }
        ICreatorTokenTransferValidator(validator).applyListToCollection(address(this), listId);
    }

    /**
     * @dev Reserved storage gap for future upgrades
     */
    uint256[48] private __gap;
}
