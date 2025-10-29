// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
  REITToken
  - ERC20 token representing shares of a single REIT/property.
  - On creation, mints totalSupply:
      - 30% to companyAddress
      - remaining 70% to issuer (property owner / creator)
  - Enforces maxHoldPercent (default 9%) per wallet (configurable by owner)
  - Exemptions allowed (company, swap contract, router, etc.)
  - Owner (issuer) can pause transfers
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract REITToken is ERC20, Pausable, Ownable, ReentrancyGuard {
    address public company;          // company address that receives 30%
    uint256 public immutable totalSupplyCap; // total supply (fixed)
    uint256 public maxHoldPercent = 9; // percent (integer)
    mapping(address => bool) public exempt; // addresses exempt from max-hold rule

    event ExemptSet(address indexed who, bool ok);
    event MaxHoldPercentSet(uint256 percent);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 supply_,           // total supply in wei (e.g., 1e18 * N)
        address companyAddress_,   // company receives 30%
        address issuerAddress_     // issuer / property owner receives remaining 70%
    ) ERC20(name_, symbol_) {
        require(companyAddress_ != address(0), "company zero");
        require(issuerAddress_ != address(0), "issuer zero");
        require(supply_ > 0, "supply zero");

        company = companyAddress_;
        totalSupplyCap = supply_;

        // calculate portions
        uint256 companyShare = (supply_ * 30) / 100; // 30%
        uint256 issuerShare = supply_ - companyShare; // remaining 70%

        // mint both
        _mint(companyAddress_, companyShare);
        _mint(issuerAddress_, issuerShare);

        // exempt the company & issuer by default
        exempt[companyAddress_] = true;
        exempt[issuerAddress_] = true;
    }

    // Pause/unpause (owner = issuer)
    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }

    // Set exemptions for addresses (e.g., swap contract, marketplace)
    function setExempt(address who, bool ok) external onlyOwner {
        exempt[who] = ok;
        emit ExemptSet(who, ok);
    }

    // Set max hold percent (admin)
    function setMaxHoldPercent(uint256 percent) external onlyOwner {
        require(percent <= 100, "percent>100");
        maxHoldPercent = percent;
        emit MaxHoldPercentSet(percent);
    }

    // helper: compute max allowed tokens per wallet
    function maxHold() public view returns (uint256) {
        return (totalSupplyCap * maxHoldPercent) / 100;
    }

    // Override transfer hook to enforce per-wallet cap and pause
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "token paused");

        // If receiving account is not exempt and not zero (minting handled in constructor only),
        // ensure resulting balance <= maxHold()
        if (to != address(0) && !exempt[to]) {
            uint256 newBalance = balanceOf(to) + amount;
            require(newBalance <= maxHold(), "exceeds max per-wallet");
        }
    }
}
