// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @title ITransferValidator
 * @author Limit Break, Inc.
 * @notice Interface for transfer validator contracts that validate token transfers
 */
interface ITransferValidator {
    /// @notice Validates a token transfer (ERC721)
    /// @param caller The address initiating the transfer
    /// @param from The address sending the token
    /// @param to The address receiving the token
    /// @param tokenId The ID of the token being transferred
    function validateTransfer(
        address caller,
        address from,
        address to,
        uint256 tokenId
    ) external view;

    /// @notice Validates a token transfer with amount (ERC1155/ERC20)
    /// @param caller The address initiating the transfer
    /// @param from The address sending the token
    /// @param to The address receiving the token
    /// @param tokenId The ID of the token being transferred (0 for ERC20)
    /// @param amount The amount of tokens being transferred
    function validateTransfer(
        address caller,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external view;

    /// @notice Applies collection transfer policy (post-transfer validation)
    /// @param caller The address initiating the transfer
    /// @param from The address sending the token
    /// @param to The address receiving the token
    function applyCollectionTransferPolicy(
        address caller,
        address from,
        address to
    ) external view;
}

/**
 * @title ICreatorTokenTransferValidator
 * @author Limit Break, Inc.
 * @notice Extended interface for transfer validator with security policy management
 */
interface ICreatorTokenTransferValidator is ITransferValidator {
    /// @notice Sets the collection to use the default security policy
    /// @param collection The address of the token collection
    function setTransferSecurityLevelOfCollection(
        address collection,
        uint8 level
    ) external;

    /// @notice Gets the security level of a collection
    /// @param collection The address of the token collection
    function getCollectionSecurityPolicy(address collection) 
        external 
        view 
        returns (
            uint8 transferSecurityLevel,
            uint120 listId
        );

    /// @notice Applies a list to a collection for whitelist/blacklist functionality
    /// @param collection The address of the token collection
    /// @param id The list ID to apply
    function applyListToCollection(address collection, uint120 id) external;

    /// @notice Gets the default transfer security level
    function DEFAULT_TRANSFER_SECURITY_LEVEL() external view returns (uint8);
}

/**
 * @title ITransferValidatorSetTokenType
 * @author Limit Break, Inc.
 * @notice Interface for registering token type with transfer validator
 */
interface ITransferValidatorSetTokenType {
    function setTokenTypeOfCollection(address collection, uint16 tokenType) external;
}

/**
 * @title IEOARegistry
 * @author Limit Break, Inc.
 * @notice Interface for EOA Registry
 */
interface IEOARegistry {
    function isVerifiedEOA(address account) external view returns (bool);
}
