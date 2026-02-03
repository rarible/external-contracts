// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

/// @author rarible

import "./DropERC721FlatFee.sol";
import "../../extension/CreatorTokenBase.sol";
import "../../extension/AutomaticValidatorTransferApproval.sol";
import "../../extension/interface/ICreatorTokenLegacy.sol";

/**
 * @title DropERC721FlatFeeC
 * @author rarible
 * @notice ERC721 Drop with Flat Fee and Creator Token Standard (ERC721-C) support.
 */
contract DropERC721FlatFeeC is
    DropERC721FlatFee,
    CreatorTokenBase,
    AutomaticValidatorTransferApproval
{
    /*///////////////////////////////////////////////////////////////
                    Constructor + initializer logic
    //////////////////////////////////////////////////////////////*/

    constructor() initializer {}

    /// @dev Initializes the contract.
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

        transferRole = _transferRole;
        minterRole = _minterRole;
        metadataRole = _metadataRole;

        // Initialize Creator Token
        _initializeCreatorToken();
        _initializeAutoApproval();
    }

    /*///////////////////////////////////////////////////////////////
                        ERC 165
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return 
            interfaceId == type(ICreatorToken).interfaceId || 
            interfaceId == type(ICreatorTokenLegacy).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /*///////////////////////////////////////////////////////////////
                        Contract identifiers
    //////////////////////////////////////////////////////////////*/

    function contractType() external pure override returns (bytes32) {
        return bytes32("DropERC721FlatFeeC");
    }

    function contractVersion() external pure override returns (uint8) {
        return uint8(1);
    }

    /*///////////////////////////////////////////////////////////////
                        OwnablePermissions
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns true if caller has DEFAULT_ADMIN_ROLE (contract owner equivalent).
    function _requireCallerIsContractOwner() internal view override {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert("Not authorized");
        }
    }

    /*///////////////////////////////////////////////////////////////
                        Creator Token Functions
    //////////////////////////////////////////////////////////////*/

    function isApprovedForAll(address owner_, address operator) public view virtual override returns (bool) {
        if (autoApproveTransfersFromValidator && operator == getTransferValidator()) {
            return true;
        }
        return super.isApprovedForAll(owner_, operator);
    }

    /*///////////////////////////////////////////////////////////////
                        Transfer Validation
    //////////////////////////////////////////////////////////////*/

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId_,
        uint256 quantity
    ) internal virtual override {
        super._beforeTokenTransfers(from, to, startTokenId_, quantity);

        // Validate transfers (skip mint/burn)
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < quantity;) {
                _preValidateTransfer(_msgSender(), from, to, startTokenId_ + i);
                unchecked { ++i; }
            }
        }
    }
}
