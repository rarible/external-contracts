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
import "../../extension/PlatformFee.sol";
import "../../extension/Royalty.sol";
import "../../extension/PrimarySale.sol";
import "../../extension/Ownable.sol";
import "../../extension/DelayedReveal.sol";
import "../../extension/LazyMint.sol";
import "../../extension/PermissionsEnumerable.sol";
import "../../extension/Drop.sol";

//  ==========  Creator Token    ==========

import "../../extension/CreatorTokenBase.sol";
import "../../extension/AutomaticValidatorTransferApproval.sol";
import "../../extension/interface/ICreatorTokenLegacy.sol";

/**
 * @title DropERC721FlatFeeCLite
 * @author rarible
 * @notice Flat ERC721 Drop with Flat Fee and Creator Token Standard (ERC721-C) support.
 * @dev Lite version: uses ERC721A instead of ERC721AQueryable (keeps PermissionsEnumerable).
 *      Flat inheritance — all logic inlined for better thirdweb compatibility.
 */
contract DropERC721FlatFeeCLite is
    Initializable,
    ContractMetadata,
    PlatformFee,
    Royalty,
    PrimarySale,
    Ownable,
    DelayedReveal,
    LazyMint,
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

    /// @dev Only transfers to or from TRANSFER_ROLE holders are valid, when transfers are restricted.
    bytes32 internal transferRole;
    /// @dev Only MINTER_ROLE holders can sign off on `MintRequest`s and lazy mint tokens.
    bytes32 internal minterRole;
    /// @dev Only METADATA_ROLE holders can reveal the URI for a batch of delayed reveal NFTs, and update or freeze batch metadata.
    bytes32 internal metadataRole;

    /// @dev Max bps in the thirdweb system.
    uint256 private constant MAX_BPS = 10_000;

    address public constant DEFAULT_FEE_RECIPIENT = 0x053F171c0D0Cc9d76247D4d1CdDb280bf1131390;
    uint16 public constant DEFAULT_FEE_BPS = 0;

    /// @dev Global max total supply of NFTs.
    uint256 public maxTotalSupply;

    /// @dev Emitted when the global max supply of tokens is updated.
    event MaxTotalSupplyUpdated(uint256 maxTotalSupply);

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
        uint128 _royaltyBps
    ) external initializer {
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

        _setupPlatformFeeInfo(DEFAULT_FEE_RECIPIENT, DEFAULT_FEE_BPS);
        _setupDefaultRoyaltyInfo(_royaltyRecipient, _royaltyBps);
        _setupPrimarySaleRecipient(_saleRecipient);

        transferRole = _transferRole;
        minterRole = _minterRole;
        metadataRole = _metadataRole;

        nextTokenIdToLazyMint = _startTokenId();

        _initializeCreatorToken();
        _initializeAutoApproval();
    }

    /*///////////////////////////////////////////////////////////////
                        ERC 165 / 721 / 2981 logic
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the URI for a given tokenId.
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        (uint256 batchId, ) = _getBatchId(_tokenId);
        string memory batchUri = _getBaseURI(_tokenId);

        if (isEncryptedBatch(batchId)) {
            return string(abi.encodePacked(batchUri, "0"));
        } else {
            return string(abi.encodePacked(batchUri, _tokenId.toString()));
        }
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function startTokenId() public pure returns (uint256) {
        return _startTokenId();
    }

    /// @dev See ERC 165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721AUpgradeable, IERC165) returns (bool) {
        return
            interfaceId == type(ICreatorToken).interfaceId ||
            interfaceId == type(ICreatorTokenLegacy).interfaceId ||
            interfaceId == type(IERC2981Upgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /*///////////////////////////////////////////////////////////////
                        Contract identifiers
    //////////////////////////////////////////////////////////////*/

    function contractType() external pure returns (bytes32) {
        return bytes32("DropERC721FlatFeeCLite");
    }

    function contractVersion() external pure returns (uint8) {
        return uint8(3);
    }

    /*///////////////////////////////////////////////////////////////
                    Lazy minting + delayed-reveal logic
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Lets an account with `MINTER_ROLE` lazy mint 'n' NFTs.
     *      The URIs for each token is the provided `_baseURIForTokens` + `{tokenId}`.
     */
    function lazyMint(
        uint256 _amount,
        string calldata _baseURIForTokens,
        bytes calldata _data
    ) public override returns (uint256 batchId) {
        if (_data.length > 0) {
            (bytes memory encryptedURI, bytes32 provenanceHash) = abi.decode(_data, (bytes, bytes32));
            if (encryptedURI.length != 0 && provenanceHash != "") {
                _setEncryptedData(nextTokenIdToLazyMint + _amount, _data);
            }
        }

        return super.lazyMint(_amount, _baseURIForTokens, _data);
    }

    /// @dev Lets an account with `METADATA_ROLE` reveal the URI for a batch of 'delayed-reveal' NFTs.
    /// @param _index the ID of a token with the desired batch.
    /// @param _key the key to decrypt the batch's URI.
    function reveal(
        uint256 _index,
        bytes calldata _key
    ) external onlyRole(metadataRole) returns (string memory revealedURI) {
        uint256 batchId = getBatchIdAtIndex(_index);
        revealedURI = getRevealURI(batchId, _key);

        _setEncryptedData(batchId, "");
        _setBaseURI(batchId, revealedURI);

        emit TokenURIRevealed(_index, revealedURI);
    }

    /**
     * @notice Updates the base URI for a batch of tokens. Can only be called if the batch has been revealed/is not encrypted.
     *
     * @param _index Index of the desired batch in batchIds array
     * @param _uri   the new base URI for the batch.
     */
    function updateBatchBaseURI(uint256 _index, string calldata _uri) external onlyRole(metadataRole) {
        require(!isEncryptedBatch(getBatchIdAtIndex(_index)), "Encrypted batch");
        uint256 batchId = getBatchIdAtIndex(_index);
        _setBaseURI(batchId, _uri);
    }

    /**
     * @notice Freezes the base URI for a batch of tokens.
     *
     * @param _index Index of the desired batch in batchIds array.
     */
    function freezeBatchBaseURI(uint256 _index) external onlyRole(metadataRole) {
        require(!isEncryptedBatch(getBatchIdAtIndex(_index)), "Encrypted batch");
        uint256 batchId = getBatchIdAtIndex(_index);
        _freezeBaseURI(batchId);
    }

    /*///////////////////////////////////////////////////////////////
                        Setter functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Lets a contract admin set the global maximum supply for collection's NFTs.
    function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxTotalSupply = _maxTotalSupply;
        emit MaxTotalSupplyUpdated(_maxTotalSupply);
    }

    /*///////////////////////////////////////////////////////////////
                        Internal functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Runs before every `claim` function call.
    function _beforeClaim(
        address,
        uint256 _quantity,
        address,
        uint256,
        AllowlistProof calldata,
        bytes memory
    ) internal view override {
        require(_currentIndex + _quantity <= nextTokenIdToLazyMint, "!Tokens");
        require(maxTotalSupply == 0 || _currentIndex + _quantity <= maxTotalSupply, "!Supply");
    }

    /// @dev Collects and distributes the primary sale value of NFTs being claimed.
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

    /// @dev Transfers the NFTs being claimed.
    function _transferTokensOnClaim(
        address _to,
        uint256 _quantityBeingClaimed
    ) internal override returns (uint256 startTokenId_) {
        startTokenId_ = _currentIndex;
        _safeMint(_to, _quantityBeingClaimed);
    }

    function _canSetPlatformFeeInfo() internal view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
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

    function _canLazyMint() internal view virtual override returns (bool) {
        return hasRole(minterRole, _msgSender());
    }

    function _requireCallerIsContractOwner() internal view override {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) revert("!Auth");
    }

    /*///////////////////////////////////////////////////////////////
                        Miscellaneous
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the total amount of tokens minted in the contract.
    function totalMinted() external view returns (uint256) {
        return _totalMinted();
    }

    /// @dev The tokenId of the next NFT that will be minted / lazy minted.
    function nextTokenIdToMint() external view returns (uint256) {
        return nextTokenIdToLazyMint;
    }

    /// @dev The next token ID of the NFT that can be claimed.
    function nextTokenIdToClaim() external view returns (uint256) {
        return _currentIndex;
    }

    /// @dev Burns `tokenId`. See {ERC721-_burn}.
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
