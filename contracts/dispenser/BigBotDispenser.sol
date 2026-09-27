// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title BigBotDispenser — fixed-price sale of BIGBOT for PLS (no buyback, no proxy)
/// @notice Sells BIGBOT at a fixed PLS price. Never buys tokens back. Optional per-address
///         and per-day global caps. Owner may withdraw PLS and unsold BIGBOT, pause sales,
///         and (if enabled) raise price only. Designed so the sale price acts as a ceiling
///         on any secondary market.
interface IERC20Dispenser {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract BigBotDispenser {
    IERC20Dispenser public immutable bigbot;
    address public owner;

    /// @dev PLS wei per 1 raw BIGBOT unit (token has 6 decimals; 1 BIGBOT = 1e6 raw).
    ///      Example: pricePerRaw = 1000 * 1e18 / 1e6 means 1000 PLS per 1 whole BIGBOT.
    uint256 public pricePerRaw;
    uint256 public immutable maxPerAddress; // raw BIGBOT units
    uint256 public maxPerDayGlobal; // raw; 0 = disabled

    bool public paused;
    bool public immutable priceOnlyIncrease; // if true, setPrice may only raise price

    mapping(address => uint256) public purchased; // raw bought per address
    uint256 public soldToday;
    uint256 public soldDayStart; // block.timestamp / 1 days

    bool private _locked;

    event Bought(address indexed buyer, uint256 bigbotRaw, uint256 plsPaid, uint256 newPurchased);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event Paused(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event WithdrawnPLS(address indexed to, uint256 amount);
    event WithdrawnBIGBOT(address indexed to, uint256 amount);
    event MaxPerDayUpdated(uint256 oldCap, uint256 newCap);

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error PausedErr();
    error CapAddress();
    error CapDay();
    error InsufficientBIGBOT();
    error InsufficientPLS();
    error BadPrice();
    error PriceDecreaseForbidden();
    error Reentrant();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier nonReentrant() {
        if (_locked) revert Reentrant();
        _locked = true;
        _;
        _locked = false;
    }

    /// @param bigbot_ BIGBOT token
    /// @param pricePerRaw_ PLS wei charged per 1 raw BIGBOT (1e-6 token)
    /// @param maxPerAddress_ max raw BIGBOT one address may buy (lifetime)
    /// @param maxPerDayGlobal_ max raw sold per UTC-ish day (0 = off)
    /// @param priceOnlyIncrease_ if true, owner can only raise price
    constructor(
        address bigbot_,
        uint256 pricePerRaw_,
        uint256 maxPerAddress_,
        uint256 maxPerDayGlobal_,
        bool priceOnlyIncrease_
    ) {
        if (bigbot_ == address(0)) revert ZeroAddress();
        if (pricePerRaw_ == 0) revert BadPrice();
        if (maxPerAddress_ == 0) revert ZeroAmount();
        bigbot = IERC20Dispenser(bigbot_);
        owner = msg.sender;
        pricePerRaw = pricePerRaw_;
        maxPerAddress = maxPerAddress_;
        maxPerDayGlobal = maxPerDayGlobal_;
        priceOnlyIncrease = priceOnlyIncrease_;
        emit OwnershipTransferred(address(0), msg.sender);
        emit PriceUpdated(0, pricePerRaw_);
    }

    /// @notice Buy `bigbotRaw` units. msg.value must be exactly bigbotRaw * pricePerRaw.
    function buy(uint256 bigbotRaw) external payable nonReentrant {
        if (paused) revert PausedErr();
        if (bigbotRaw == 0) revert ZeroAmount();

        uint256 cost = bigbotRaw * pricePerRaw;
        if (msg.value != cost) revert InsufficientPLS();

        uint256 newPurchased = purchased[msg.sender] + bigbotRaw;
        if (newPurchased > maxPerAddress) revert CapAddress();

        uint256 day = block.timestamp / 1 days;
        if (day != soldDayStart) {
            soldDayStart = day;
            soldToday = 0;
        }
        if (maxPerDayGlobal != 0 && soldToday + bigbotRaw > maxPerDayGlobal) revert CapDay();

        uint256 bal = bigbot.balanceOf(address(this));
        if (bal < bigbotRaw) revert InsufficientBIGBOT();

        // Effects
        purchased[msg.sender] = newPurchased;
        soldToday += bigbotRaw;

        // Interaction
        if (!bigbot.transfer(msg.sender, bigbotRaw)) revert TransferFailed();

        emit Bought(msg.sender, bigbotRaw, msg.value, newPurchased);
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    function setPrice(uint256 newPricePerRaw) external onlyOwner {
        if (newPricePerRaw == 0) revert BadPrice();
        if (priceOnlyIncrease && newPricePerRaw < pricePerRaw) revert PriceDecreaseForbidden();
        uint256 old = pricePerRaw;
        pricePerRaw = newPricePerRaw;
        emit PriceUpdated(old, newPricePerRaw);
    }

    function setMaxPerDayGlobal(uint256 newCap) external onlyOwner {
        uint256 old = maxPerDayGlobal;
        maxPerDayGlobal = newCap;
        emit MaxPerDayUpdated(old, newCap);
    }

    function withdrawPLS(address payable to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0 || address(this).balance < amount) revert InsufficientPLS();
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit WithdrawnPLS(to, amount);
    }

    function withdrawBIGBOT(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (!bigbot.transfer(to, amount)) revert TransferFailed();
        emit WithdrawnBIGBOT(to, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Quote PLS wei needed for `bigbotRaw` units.
    function quote(uint256 bigbotRaw) external view returns (uint256) {
        return bigbotRaw * pricePerRaw;
    }

    receive() external payable {
        revert InsufficientPLS(); // force use of buy()
    }
}
