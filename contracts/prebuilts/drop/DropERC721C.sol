// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

/// @author rarible

// $$$$$$$\                      $$\ $$\       $$\           
// $$  __$$\                     \__|$$ |      $$ |          
// $$ |  $$ | $$$$$$\   $$$$$$\  $$\ $$$$$$$\  $$ | $$$$$$\  
// $$$$$$$  | \____$$\ $$  __$$\ $$ |$$  __$$\ $$ |$$  __$$\ 
// $$  __$$<  $$$$$$$ |$$ |  \__|$$ |$$ |  $$ |$$ |$$$$$$$$ |
// $$ |  $$ |$$  __$$ |$$ |      $$ |$$ |  $$ |$$ |$$   ____|
// $$ |  $$ |\$$$$$$$ |$$ |      $$ |$$$$$$$  |$$ |\$$$$$$$\ 
// \__|  \__| \_______|\__|      \__|\_______/ \__| \_______|                                                          

import "./DropERC721.sol";
import "../../extension/upgradeable/CreatorTokenBaseUpgradeable.sol";
import "../../extension/upgradeable/AutomaticValidatorTransferApprovalUpgradeable.sol";
import "../../extension/interface/ICreatorToken.sol";
import "../../extension/interface/ICreatorTokenLegacy.sol";
import "../../extension/interface/ITransferValidator.sol";

/**
 * @title DropERC721C
 * @author rarible
 * @notice ERC721 Drop contract with Creator Token Standard (ERC721-C) support.
 *         Extends the standard DropERC721 with transfer validation functionality,
 *         allowing the contract owner to manage transfer policies through an external
 *         transfer validation security policy registry.
 * @dev Based on Limit Break's Creator Token Standards:
 *      https://github.com/limitbreakinc/creator-token-standards
 */
contract DropERC721C is
    DropERC721,
    CreatorTokenBaseUpgradeable,
    AutomaticValidatorTransferApprovalUpgradeable
{
    /*///////////////////////////////////////////////////////////////
                    Constructor + initializer logic
    //////////////////////////////////////////////////////////////*/

    constructor() initializer {}

    /// @dev Initializes the contract, like a constructor.
    function initialize(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        string memory _contractURI,
        address[] memory _trustedForwarders,
        address _saleRecipient,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        uint128 _platformFeeBps,
        address _platformFeeRecipient
    ) external override initializer {
        // Initialize base DropERC721
        bytes32 _transferRole = keccak256("TRANSFER_ROLE");
        bytes32 _minterRole = keccak256("MINTER_ROLE");
        bytes32 _metadataRole = keccak256("METADATA_ROLE");

        __ERC2771Context_init(_trustedForwarders);
        __ERC721A_init(_name, _symbol);

        _setupContractURI(_contractURI);
        _setupOwner(_defaultAdmin);

        _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _setupRole(_minterRole, _defaultAdmin);
        _setupRole(_transferRole, _defaultAdmin);
        _setupRole(_transferRole, address(0));
        _setupRole(_metadataRole, _defaultAdmin);
        _setRoleAdmin(_metadataRole, _metadataRole);

        _setupPlatformFeeInfo(_platformFeeRecipient, _platformFeeBps);
        _setupDefaultRoyaltyInfo(_royaltyRecipient, _royaltyBps);
        _setupPrimarySaleRecipient(_saleRecipient);

        // Initialize Creator Token Standard
        __CreatorTokenBase_init();
        __AutomaticValidatorTransferApproval_init();
    }

    /*///////////////////////////////////////////////////////////////
                        ERC 165 / 721 / 2981 logic
    //////////////////////////////////////////////////////////////*/

    /// @dev See ERC 165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return 
            interfaceId == type(ICreatorToken).interfaceId || 
            interfaceId == type(ICreatorTokenLegacy).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /*///////////////////////////////////////////////////////////////
                        Contract identifiers
    //////////////////////////////////////////////////////////////*/

    function contractType() external pure override returns (bytes32) {
        return bytes32("DropERC721C");
    }

    function contractVersion() external pure override returns (uint8) {
        return uint8(1);
    }

    /*///////////////////////////////////////////////////////////////
                        Creator Token Standard
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Overrides behavior of isApprovedForAll such that if an operator is not explicitly approved
     *         for all, the contract owner can optionally auto-approve the 721-C transfer validator for transfers.
     */
    function isApprovedForAll(address owner_, address operator) public view virtual override returns (bool isApproved) {
        isApproved = super.isApprovedForAll(owner_, operator);

        if (!isApproved) {
            if (autoApproveTransfersFromValidator()) {
                isApproved = operator == getTransferValidator();
            }
        }
    }

    /**
     * @notice Sets the transfer validator contract address
     * @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
     * @param validator The address of the new transfer validator
     */
    function setTransferValidator(address validator) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTransferValidator(validator);
    }

    /**
     * @notice Sets whether the transfer validator should be auto-approved for all transfers
     * @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
     * @param autoApprove Whether to auto-approve the transfer validator
     */
    function setAutomaticApprovalOfTransfersFromValidator(bool autoApprove) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setAutomaticApprovalOfTransfersFromValidator(autoApprove);
    }

    /**
     * @notice Sets the collection to use the default security policy on the transfer validator
     * @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
     */
    function setToDefaultSecurityPolicy() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        address validator = getTransferValidator();
        if (validator != address(0)) {
            try ICreatorTokenTransferValidator(validator).DEFAULT_TRANSFER_SECURITY_LEVEL() 
                returns (uint8 defaultLevel) 
            {
                _setTransferSecurityLevel(defaultLevel);
            } catch {
                // If the validator doesn't support the function, set to level 0 (most permissive)
                _setTransferSecurityLevel(0);
            }
        }
    }

    /**
     * @notice Sets a custom security level for the collection
     * @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
     * @param level The security level to set (0 = most permissive, higher = more restrictive)
     */
    function setToCustomSecurityPolicy(uint8 level) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTransferSecurityLevel(level);
    }

    /**
     * @notice Sets a custom security policy with a specific list ID (whitelist/blacklist)
     * @dev Only callable by accounts with DEFAULT_ADMIN_ROLE
     * @param level The security level to set
     * @param listId The list ID to apply for whitelist/blacklist functionality
     */
    function setToCustomSecurityPolicyWithList(uint8 level, uint120 listId) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTransferSecurityLevel(level);
        _applyListToCollection(listId);
    }

    /*///////////////////////////////////////////////////////////////
                        Transfer Hooks
    //////////////////////////////////////////////////////////////*/

    /// @dev See {ERC721-_beforeTokenTransfer}. Integrates Creator Token transfer validation.
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId_,
        uint256 quantity
    ) internal virtual override {
        // Call parent implementation (handles transfer role restrictions)
        super._beforeTokenTransfers(from, to, startTokenId_, quantity);

        // Creator Token Standard: validate transfers through transfer validator
        // Uses _validateBeforeTransfer which routes to _preValidateMint/_preValidateBurn/_preValidateTransfer
        for (uint256 i = 0; i < quantity;) {
            _validateBeforeTransfer(from, to, startTokenId_ + i);
            unchecked {
                ++i;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                        Context overrides
    //////////////////////////////////////////////////////////////*/

    function _msgSender()
        internal
        view
        virtual
        override(DropERC721, ContextUpgradeable)
        returns (address sender)
    {
        return DropERC721._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(DropERC721, ContextUpgradeable)
        returns (bytes calldata)
    {
        return DropERC721._msgData();
    }
}
