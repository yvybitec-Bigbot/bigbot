// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BotVault_v2.sol";

/// @title BotVaultFactory v2 — deploys BotVault v2; optional create-time BIGBOT burn
contract BotVaultFactory {
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    address public immutable createBurnToken; // BIGBOT / signal token
    uint256 public immutable createBurnAmount; // 0 = disabled
    address public immutable createBurnSink; // DEAD

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
    event CreateBurned(address indexed vault, address indexed payer, uint256 amount, address sink);

    error SameRoles();
    error ZeroAddress();
    error TransferFailed();

    /// @param createBurnToken_ token burned on create (typically BIGBOT); address(0) + amount 0 ok if disabled
    /// @param createBurnAmount_ raw units burned per createVault (0 = off)
    /// @param createBurnSink_ burn destination (use DEAD)
    constructor(address createBurnToken_, uint256 createBurnAmount_, address createBurnSink_) {
        if (createBurnAmount_ > 0) {
            if (createBurnToken_ == address(0) || createBurnSink_ == address(0)) revert ZeroAddress();
        }
        createBurnToken = createBurnToken_;
        createBurnAmount = createBurnAmount_;
        createBurnSink = createBurnSink_ == address(0) ? DEAD : createBurnSink_;
    }

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

        uint256 burnAmt = createBurnAmount;
        if (burnAmt > 0) {
            if (!IERC20(createBurnToken).transferFrom(msg.sender, createBurnSink, burnAmt)) {
                revert TransferFailed();
            }
        }

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
        if (burnAmt > 0) {
            emit CreateBurned(vault, msg.sender, burnAmt, createBurnSink);
        }
    }

    function vaultCount() external view returns (uint256) {
        return allVaults.length;
    }
}
