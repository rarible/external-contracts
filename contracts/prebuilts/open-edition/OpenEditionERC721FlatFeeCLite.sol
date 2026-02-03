// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

/// @author rarible

//  ==========  External imports    ==========

import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

import "../../eip/ERC721AVirtualApproveUpgradeable.sol";

//  ==========  Internal imports    ==========

import "../../external-deps/openzeppelin/metatx/ERC2771ContextUpgradeable.sol";
import "../../lib/CurrencyTransferLib.sol";

//  ==========  Features    ==========

import "../../extension/Multicall.sol";
import "../../extension/ContractMetadata.sol";
import "../../extension/Royalty.sol";
import "../../extension/PrimarySale.sol";
import "../../extension/Ownable.sol";
import "../../extension/SharedMetadata.sol";
import "../../extension/PermissionsEnumerable.sol";
import "../../extension/Drop.sol";
import "../../extension/PlatformFee.sol";

//  ==========  Creator Token    ==========

import "../../extension/CreatorTokenBase.sol";
import "../../extension/AutomaticValidatorTransferApproval.sol";
import "../../extension/interface/ICreatorTokenLegacy.sol";

/**
 * @title OpenEditionERC721FlatFeeCLite
 * @author rarible
 * @notice Optimized Open Edition ERC721 with Flat Fee and Creator Token Standard (ERC721-C) support.
 * @dev Lite version: uses ERC721A instead of ERC721AQueryable (keeps PermissionsEnumerable)
 *      For full version with Queryable, use OpenEditionERC721FlatFeeC (L2 only due to size)
 */
contract OpenEditionERC721FlatFeeCLite is
    Initializable,
    ContractMetadata,
    PlatformFee,
    Royalty,
    PrimarySale,
    Ownable,
    SharedMetadata,
    PermissionsEnumerable,
    Drop,
    ERC2771ContextUpgradeable,
    Multicall,
    ERC721AUpgradeable,
    CreatorTokenBase,
    AutomaticValidatorTransferApproval
{
    using StringsUpgradeable for uint256;

    /*///////////////////////////////////////////////////////////////
                            State variables
    //////////////////////////////////////////////////////////////*/

    bytes32 internal transferRole;
    bytes32 internal minterRole;

    uint256 private constant MAX_BPS = 10_000;

    /*///////////////////////////////////////////////////////////////
                    Constructor + initializer logic
    //////////////////////////////////////////////////////////////*/

    constructor() initializer {}

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
    ) external initializer {
        bytes32 _transferRole = keccak256("TRANSFER_ROLE");
        bytes32 _minterRole = keccak256("MINTER_ROLE");

        __ERC2771Context_init(_trustedForwarders);
        __ERC721A_init(_name, _symbol);

        _setupContractURI(_contractURI);
        _setupOwner(_defaultAdmin);

        _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _setupRole(_minterRole, _defaultAdmin);
        _setupRole(_transferRole, _defaultAdmin);
        _setupRole(_transferRole, address(0));

        _setupPlatformFeeInfo(_platformFeeRecipient, _platformFeeBps);
        _setupDefaultRoyaltyInfo(_royaltyRecipient, _royaltyBps);
        _setupPrimarySaleRecipient(_saleRecipient);

        transferRole = _transferRole;
        minterRole = _minterRole;

        _initializeCreatorToken();
        _initializeAutoApproval();
    }

    /*///////////////////////////////////////////////////////////////
                        ERC 165 / 721 / 2981 logic
    //////////////////////////////////////////////////////////////*/

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (!_exists(_tokenId)) revert("!ID");
        return _getURIFromSharedMetadata(_tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721AUpgradeable, IERC165) returns (bool) {
        return 
            interfaceId == type(ICreatorToken).interfaceId || 
            interfaceId == type(ICreatorTokenLegacy).interfaceId ||
            interfaceId == type(IERC2981Upgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function startTokenId() public pure returns (uint256) {
        return _startTokenId();
    }

    /*///////////////////////////////////////////////////////////////
                        Contract identifiers
    //////////////////////////////////////////////////////////////*/

    function contractType() external pure returns (bytes32) {
        return bytes32("OpenEditionERC721FlatFeeCLite");
    }

    function contractVersion() external pure returns (uint8) {
        return uint8(1);
    }

    /*///////////////////////////////////////////////////////////////
                        Internal functions
    //////////////////////////////////////////////////////////////*/

    function _collectPriceOnClaim(
        address _primarySaleRecipient,
        uint256 _quantityToClaim,
        address _currency,
        uint256 _pricePerToken
    ) internal override {
        if (_pricePerToken == 0) {
            if (msg.value != 0) revert("!Value");
            return;
        }

        uint256 totalPrice = _quantityToClaim * _pricePerToken;
        uint256 platformFees;
        address platformFeeRecipient;

        if (getPlatformFeeType() == IPlatformFee.PlatformFeeType.Flat) {
            (platformFeeRecipient, platformFees) = getFlatPlatformFeeInfo();
        } else {
            (address recipient, uint16 platformFeeBps) = getPlatformFeeInfo();
            platformFeeRecipient = recipient;
            platformFees = ((totalPrice * platformFeeBps) / MAX_BPS);
        }
        if (totalPrice < platformFees) revert("!Fee");

        if (_currency == CurrencyTransferLib.NATIVE_TOKEN) {
            if (msg.value != totalPrice) revert("!V");
        } else {
            if (msg.value != 0) revert("!V");
        }

        address saleRecipient = _primarySaleRecipient == address(0) ? primarySaleRecipient() : _primarySaleRecipient;

        CurrencyTransferLib.transferCurrency(_currency, _msgSender(), platformFeeRecipient, platformFees);
        CurrencyTransferLib.transferCurrency(_currency, _msgSender(), saleRecipient, totalPrice - platformFees);
    }

    function _transferTokensOnClaim(address _to, uint256 _quantityBeingClaimed) internal override returns (uint256 startTokenId_) {
        startTokenId_ = _currentIndex;
        _safeMint(_to, _quantityBeingClaimed);
    }

    function _canSetPrimarySaleRecipient() internal view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _canSetOwner() internal view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _canSetRoyaltyInfo() internal view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _canSetContractURI() internal view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _canSetClaimConditions() internal view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _canSetSharedMetadata() internal view virtual override returns (bool) {
        return hasRole(minterRole, _msgSender());
    }

    function _canSetPlatformFeeInfo() internal view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _requireCallerIsContractOwner() internal view override {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) revert("!Auth");
    }

    /*///////////////////////////////////////////////////////////////
                        Miscellaneous
    //////////////////////////////////////////////////////////////*/

    function totalMinted() external view returns (uint256) {
        unchecked { return _currentIndex - _startTokenId(); }
    }

    function nextTokenIdToMint() external view returns (uint256) {
        return _currentIndex;
    }

    function nextTokenIdToClaim() external view returns (uint256) {
        return _currentIndex;
    }

    function burn(uint256 tokenId) external virtual {
        _burn(tokenId, true);
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

        // Transfer role check
        if (!hasRole(transferRole, address(0)) && from != address(0) && to != address(0)) {
            if (!hasRole(transferRole, from) && !hasRole(transferRole, to)) {
                revert("!T");
            }
        }

        // Creator Token validation (skip mint/burn)
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < quantity;) {
                _preValidateTransfer(_msgSender(), from, to, startTokenId_ + i);
                unchecked { ++i; }
            }
        }
    }

    function _dropMsgSender() internal view virtual override returns (address) {
        return _msgSender();
    }

    function _msgSender() internal view virtual override(ContextUpgradeable, ERC2771ContextUpgradeable, Multicall) returns (address sender) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData() internal view virtual override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }
}
