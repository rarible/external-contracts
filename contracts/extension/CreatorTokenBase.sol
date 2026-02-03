// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./OwnablePermissions.sol";
import "./interface/ICreatorToken.sol";
import "./interface/ITransferValidator.sol";

/**
 * @title CreatorTokenBase
 * @author Limit Break, Inc.
 * @notice CreatorTokenBase is an abstract contract that provides basic functionality for managing token 
 * transfer policies through an implementation of ICreatorTokenTransferValidator. 
 * This contract is intended to be used as a base for creator-specific token contracts, enabling customizable transfer 
 * restrictions and security policies.
 */
abstract contract CreatorTokenBase is OwnablePermissions, ICreatorToken {
    
    /// @dev The default transfer validator that will be used if no transfer validator has been set.
    address public constant DEFAULT_TRANSFER_VALIDATOR = address(0x721C008fdff27BF06E7E123956E2Fe03B63342e3);

    /// @dev Token type constant for ERC721
    uint16 public constant TOKEN_TYPE_ERC721 = 721;

    /// @dev Thrown when setting a transfer validator address that has no deployed code.
    error CreatorTokenBase__InvalidTransferValidatorContract();

    /// @dev Used to determine if the default transfer validator is applied.
    bool private _isValidatorInitialized;
    
    /// @dev Address of the transfer validator to apply to transactions.
    address private _transferValidator;

    /**
     * @dev Initializes creator token. Call in your initialize() function.
     */
    function _initializeCreatorToken() internal {
        emit TransferValidatorUpdated(address(0), DEFAULT_TRANSFER_VALIDATOR);
        _registerTokenType(DEFAULT_TRANSFER_VALIDATOR);
    }

    /**
     * @notice Sets the transfer validator for the token contract.
     *
     * @dev    Throws when provided validator contract is not the zero address and does not have code.
     * @dev    Throws when the caller is not the contract owner.
     *
     * @param transferValidator_ The address of the transfer validator contract.
     */
    function setTransferValidator(address transferValidator_) public {
        _requireCallerIsContractOwner();

        if (transferValidator_ != address(0) && transferValidator_.code.length == 0) {
            revert CreatorTokenBase__InvalidTransferValidatorContract();
        }

        emit TransferValidatorUpdated(getTransferValidator(), transferValidator_);
        _isValidatorInitialized = true;
        _transferValidator = transferValidator_;
        _registerTokenType(transferValidator_);
    }

    /**
     * @notice Returns the transfer validator contract address for this token contract.
     */
    function getTransferValidator() public view override returns (address validator) {
        validator = _transferValidator;
        if (validator == address(0)) {
            if (!_isValidatorInitialized) {
                validator = DEFAULT_TRANSFER_VALIDATOR;
            }
        }
    }

    /**
     * @notice Returns the function selector for the transfer validator's validation function.
     */
    function getTransferValidationFunction() external pure override returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    /**
     * @dev Pre-validates a token transfer, reverting if the transfer is not allowed by this token's security policy.
     *
     * @dev Be aware that if the msg.sender is the transfer validator, the transfer is automatically permitted, as the
     *      transfer validator is expected to pre-validate the transfer.
     *
     * @param caller  The address of the caller.
     * @param from    The address of the sender.
     * @param to      The address of the receiver.
     * @param tokenId The token id being transferred.
     */
    function _preValidateTransfer(address caller, address from, address to, uint256 tokenId) internal virtual {
        address validator = getTransferValidator();
        if (validator != address(0)) {
            if (msg.sender == validator) {
                return;
            }
            ITransferValidator(validator).validateTransfer(caller, from, to, tokenId);
        }
    }

    function _registerTokenType(address validator) internal {
        if (validator != address(0) && validator.code.length > 0) {
            try ITransferValidatorSetTokenType(validator).setTokenTypeOfCollection(address(this), _tokenType()) {} catch {}
        }
    }

    function _tokenType() internal pure virtual returns (uint16) {
        return TOKEN_TYPE_ERC721;
    }
}
