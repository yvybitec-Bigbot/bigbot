// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BotVault.sol";

/// @title BotVaultFactory — deploys immutable BotVault instances (create; no upgradeable proxy).
contract BotVaultFactory {
    address[] public allVaults;
    mapping(address => address[]) public vaultsOfBot;

    event VaultCreated(
        address indexed bot,
        address indexed vault,
        address indexed keyMaster,
        address signalToken,
        address operator,
        address allowedExit
    );

    error SameRoles();
    error ZeroAddress();

    function createVault(
        address signalToken,
        uint256 signalAmount,
        address signalSink,
        address trapAddress,
        address operator,
        address keyMaster,
        uint256 minArmDelay,
        uint256 armTTL,
        uint256 maxWithdrawBpsPerArm,
        uint256 maxArmsPerDay,
        address allowedExit
    ) external returns (address vault) {
        if (operator == address(0) || keyMaster == address(0)) revert ZeroAddress();
        if (operator == keyMaster) revert SameRoles();

        vault = address(
            new BotVault(
                signalToken,
                signalAmount,
                signalSink,
                trapAddress,
                operator,
                keyMaster,
                minArmDelay,
                armTTL,
                maxWithdrawBpsPerArm,
                maxArmsPerDay,
                allowedExit
            )
        );

        allVaults.push(vault);
        vaultsOfBot[operator].push(vault);
        emit VaultCreated(operator, vault, keyMaster, signalToken, operator, allowedExit);
    }

    function vaultCount() external view returns (uint256) {
        return allVaults.length;
    }
}
