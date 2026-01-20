// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @title OwnablePermissions
 * @author Limit Break, Inc.
 * @notice Abstract contract that requires implementing `_requireCallerIsContractOwner`.
 */
abstract contract OwnablePermissions {
    function _requireCallerIsContractOwner() internal view virtual;
}
