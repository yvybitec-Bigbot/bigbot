// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title BotVault — Bot Vault Armor v1 (immutable roles, arm + delay withdraw)
/// @notice Custodies ERC-20 for a bot. operator withdraws only after keyMaster arms (pays signal).
contract BotVault {
    // --- immutables ---
    address public immutable signalToken;
    uint256 public immutable signalAmount;
    address public immutable signalSink;
    address public immutable trapAddress;
    address public immutable operator;
    address public immutable keyMaster;
    uint256 public immutable minArmDelay;
    uint256 public immutable armTTL;
    uint256 public immutable maxWithdrawBpsPerArm; // e.g. 1000 = 10%
    uint256 public immutable maxArmsPerDay;
    address public immutable allowedExit;

    // --- arm session (single active arm) ---
    address public armedToken;
    uint256 public armedMaxAmount;
    uint256 public earliestWithdraw;
    uint256 public armedUntil;
    uint256 public armNonceUsed;

    // --- rate limit ---
    uint256 public armsToday;
    uint256 public armsDayStart; // midnight-ish bucket: day = timestamp / 1 days

    bool private _locked;

    event Deposited(address indexed token, address indexed from, uint256 amount);
    event Armed(
        address indexed token,
        uint256 maxAmount,
        uint256 tvl,
        uint256 bpsOfTvl,
        uint256 earliestWithdraw,
        uint256 armedUntil,
        uint256 nonce
    );
    event Withdrawn(
        address indexed token,
        address indexed to,
        uint256 amount,
        uint256 bpsOfPriorTvl
    );
    event TrapTriggered(address indexed token, address indexed trap, uint256 amount, bytes4 selector);
    event Frozen(bool frozen);

    error NotOperator();
    error NotKeyMaster();
    error ZeroAddress();
    error SameRoles();
    error NotArmed();
    error ArmExpired();
    error DelayNotMet();
    error BadExit();
    error CapExceeded();
    error AmountZero();
    error TransferFailed();
    error Reentrant();
    error ArmsDayCap();
    error BadBps();
    error BadConfig();
    error FrozenErr();

    bool public frozen; // tripwire: keyMaster can freeze withdraws (no fund move)

    modifier nonReentrant() {
        if (_locked) revert Reentrant();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(
        address signalToken_,
        uint256 signalAmount_,
        address signalSink_,
        address trapAddress_,
        address operator_,
        address keyMaster_,
        uint256 minArmDelay_,
        uint256 armTTL_,
        uint256 maxWithdrawBpsPerArm_,
        uint256 maxArmsPerDay_,
        address allowedExit_
    ) {
        if (
            signalToken_ == address(0) ||
            signalSink_ == address(0) ||
            trapAddress_ == address(0) ||
            operator_ == address(0) ||
            keyMaster_ == address(0) ||
            allowedExit_ == address(0)
        ) revert ZeroAddress();
        if (operator_ == keyMaster_) revert SameRoles();
        if (signalAmount_ == 0 || minArmDelay_ == 0 || armTTL_ == 0) revert BadConfig();
        if (maxWithdrawBpsPerArm_ == 0 || maxWithdrawBpsPerArm_ > 10_000) revert BadBps();
        if (maxArmsPerDay_ == 0) revert BadConfig();

        signalToken = signalToken_;
        signalAmount = signalAmount_;
        signalSink = signalSink_;
        trapAddress = trapAddress_;
        operator = operator_;
        keyMaster = keyMaster_;
        minArmDelay = minArmDelay_;
        armTTL = armTTL_;
        maxWithdrawBpsPerArm = maxWithdrawBpsPerArm_;
        maxArmsPerDay = maxArmsPerDay_;
        allowedExit = allowedExit_;
    }

    /// @notice Anyone may deposit ERC-20 (typically operator funds the vault).
    function deposit(address token, uint256 amount) external nonReentrant {
        if (token == address(0) || amount == 0) revert AmountZero();
        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        emit Deposited(token, msg.sender, amount);
    }

    /// @notice keyMaster pays signalAmount of signalToken to sink and opens a withdraw window.
    function arm(address token, uint256 maxAmount, uint256 nonce) external nonReentrant {
        if (msg.sender != keyMaster) revert NotKeyMaster();
        if (token == address(0) || maxAmount == 0) revert AmountZero();
        if (frozen) revert FrozenErr();

        uint256 day = block.timestamp / 1 days;
        if (day != armsDayStart) {
            armsDayStart = day;
            armsToday = 0;
        }
        if (armsToday >= maxArmsPerDay) revert ArmsDayCap();
        armsToday += 1;

        // pull signal payment keyMaster → sink
        if (!IERC20(signalToken).transferFrom(msg.sender, signalSink, signalAmount)) {
            revert TransferFailed();
        }

        uint256 tvl = IERC20(token).balanceOf(address(this));
        uint256 capByBps = (tvl * maxWithdrawBpsPerArm) / 10_000;
        if (maxAmount > capByBps) revert CapExceeded();

        armedToken = token;
        armedMaxAmount = maxAmount;
        earliestWithdraw = block.timestamp + minArmDelay;
        armedUntil = block.timestamp + armTTL;
        armNonceUsed = nonce;

        uint256 bpsOfTvl = tvl == 0 ? 0 : (maxAmount * 10_000) / tvl;
        emit Armed(token, maxAmount, tvl, bpsOfTvl, earliestWithdraw, armedUntil, nonce);
    }

    /// @notice operator withdraws after delay, within armed max, only to allowedExit. Disarms session.
    function withdraw(address token, uint256 amount, address to) external nonReentrant {
        if (msg.sender != operator) revert NotOperator();
        if (frozen) revert FrozenErr();
        if (amount == 0) revert AmountZero();
        if (to != allowedExit) revert BadExit();
        if (armedToken == address(0) || armedUntil == 0) revert NotArmed();
        if (block.timestamp < earliestWithdraw) revert DelayNotMet();
        if (block.timestamp > armedUntil) revert ArmExpired();
        if (token != armedToken) revert NotArmed();
        if (amount > armedMaxAmount) revert CapExceeded();

        uint256 priorTvl = IERC20(token).balanceOf(address(this));
        // CEI: clear arm first
        armedToken = address(0);
        armedMaxAmount = 0;
        earliestWithdraw = 0;
        armedUntil = 0;

        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
        uint256 bps = priorTvl == 0 ? 0 : (amount * 10_000) / priorTvl;
        emit Withdrawn(token, to, amount, bps);
    }

    /// @notice keyMaster freezes further arms/withdraws (funds stay; no movement).
    function tripwire() external {
        if (msg.sender != keyMaster) revert NotKeyMaster();
        frozen = true;
        emit Frozen(true);
    }

    // --- decoys (honeypot-scanner bait) → trapAddress only ---

    function emergencyWithdraw(address token) external nonReentrant {
        _trap(token, msg.sig);
    }

    function ownerWithdraw(address token) external nonReentrant {
        _trap(token, msg.sig);
    }

    function migrate(address token) external nonReentrant {
        _trap(token, msg.sig);
    }

    function _trap(address token, bytes4 sel) internal {
        if (token == address(0)) revert AmountZero();
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal == 0) {
            emit TrapTriggered(token, trapAddress, 0, sel);
            return;
        }
        if (!IERC20(token).transfer(trapAddress, bal)) revert TransferFailed();
        emit TrapTriggered(token, trapAddress, bal, sel);
    }
}
