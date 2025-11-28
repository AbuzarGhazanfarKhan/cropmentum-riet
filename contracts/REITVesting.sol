// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
  REITVesting
  - Timelock contract for vesting company shares from REITVault deposits.
  - Company shares are minted to this contract and released linearly over time.
  - Prevents immediate sell pressure and improves trust.
  - Beneficiary (company) can claim vested tokens.
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract REITVesting is Ownable, ReentrancyGuard {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 duration; // vesting period in seconds
    }

    mapping(address => mapping(address => VestingSchedule)) public vesting; // token => beneficiary => schedule
    mapping(address => address) public beneficiary; // token => beneficiary

    event VestingSet(address indexed token, address indexed beneficiary, uint256 totalAmount, uint256 duration);
    event Claimed(address indexed token, address indexed beneficiary, uint256 amount);

    constructor() {}

    // Set vesting schedule for a token (called by vault or factory)
    function setVesting(address token, address beneficiary_, uint256 totalAmount, uint256 duration) external onlyOwner {
        require(beneficiary_ != address(0), "zero beneficiary");
        require(totalAmount > 0, "zero amount");
        require(duration > 0, "zero duration");

        vesting[token][beneficiary_] = VestingSchedule({
            totalAmount: totalAmount,
            claimedAmount: 0,
            startTime: block.timestamp,
            duration: duration
        });

        beneficiary[token] = beneficiary_;
        emit VestingSet(token, beneficiary_, totalAmount, duration);
    }

    // Calculate vested amount
    function vestedAmount(address token, address beneficiary_) public view returns (uint256) {
        VestingSchedule memory schedule = vesting[token][beneficiary_];
        if (schedule.totalAmount == 0) return 0;

        uint256 elapsed = block.timestamp - schedule.startTime;
        if (elapsed >= schedule.duration) {
            return schedule.totalAmount - schedule.claimedAmount;
        } else {
            uint256 vested = (schedule.totalAmount * elapsed) / schedule.duration;
            return vested - schedule.claimedAmount;
        }
    }

    // Claim vested tokens
    function claim(address token) external nonReentrant {
        address beneficiary_ = beneficiary[token];
        require(msg.sender == beneficiary_, "not beneficiary");

        uint256 amount = vestedAmount(token, beneficiary_);
        require(amount > 0, "nothing to claim");

        vesting[token][beneficiary_].claimedAmount += amount;

        IERC20(token).transfer(beneficiary_, amount);
        emit Claimed(token, beneficiary_, amount);
    }

    // Emergency withdraw (owner only, for stuck tokens)
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
}