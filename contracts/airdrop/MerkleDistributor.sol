// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal ERC20 interface for BIGBOT transfers.
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title MerkleDistributor — bot-only airdrop with deadline + owner sweep
/// @notice Claim with Merkle proof before endTime; owner may sweep unclaimed after.
contract MerkleDistributor {
    IERC20 public immutable token;
    bytes32 public immutable merkleRoot;
    uint256 public immutable endTime;
    address public owner;

    mapping(address => bool) public claimed;

    event Claimed(address indexed account, uint256 amount);
    event Swept(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error AlreadyClaimed();
    error ClaimWindowClosed();
    error ClaimWindowOpen();
    error InvalidProof();
    error TransferFailed();
    error ZeroAddress();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address token_, bytes32 merkleRoot_, uint256 endTime_, address owner_) {
        if (token_ == address(0) || owner_ == address(0)) revert ZeroAddress();
        require(endTime_ > block.timestamp, "endTime must be future");
        token = IERC20(token_);
        merkleRoot = merkleRoot_;
        endTime = endTime_;
        owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
    }

    /// @notice Claim `amount` for `account` with Merkle proof. Caller must be `account`.
    function claim(address account, uint256 amount, bytes32[] calldata merkleProof) external {
        if (block.timestamp > endTime) revert ClaimWindowClosed();
        if (msg.sender != account) revert InvalidProof();
        if (claimed[account]) revert AlreadyClaimed();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!_verify(merkleProof, merkleRoot, leaf)) revert InvalidProof();

        claimed[account] = true;
        if (!token.transfer(account, amount)) revert TransferFailed();
        emit Claimed(account, amount);
    }

    /// @notice After endTime, owner recovers remaining token balance (unclaimed).
    function sweep(address to) external onlyOwner {
        if (block.timestamp <= endTime) revert ClaimWindowOpen();
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = token.balanceOf(address(this));
        if (!token.transfer(to, bal)) revert TransferFailed();
        emit Swept(to, bal);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function _verify(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computed = _hashPair(computed, proof[i]);
        }
        return computed == root;
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b
            ? keccak256(abi.encodePacked(a, b))
            : keccak256(abi.encodePacked(b, a));
    }
}
