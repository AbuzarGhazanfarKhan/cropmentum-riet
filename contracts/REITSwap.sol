// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
  REITSwap
  - Simple swap contract that holds reserves of multiple REIT tokens.
  - Owner sets fixed exchange rates between token pairs (price = how many tokenTo units per 1 tokenFrom, scaled by 1e18).
  - Users call swap(tokenFrom, tokenTo, amountFrom, minAmountTo) to swap.
  - Requires user to approve tokenFrom to this contract.
  - The contract must be pre-funded with tokenTo to fulfill swaps.
  - Reentrancy guarded.
  - NOTE: For production, consider integrating with automated market makers (AMMs) or on-chain price oracles.
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract REITSwap is Ownable, ReentrancyGuard {
    // price mapping: price[tokenFrom][tokenTo] => price scaled by 1e18: tokenTo per 1 tokenFrom
    mapping(address => mapping(address => uint256)) public price;

    event PriceSet(address indexed from, address indexed to, uint256 priceScaled);
    event Swapped(address indexed user, address indexed from, address indexed to, uint256 amountFrom, uint256 amountTo);

    uint256 public constant SCALE = 1e18;

    // Set price: amount of tokenTo per 1 tokenFrom, scaled by 1e18
    function setPrice(address tokenFrom, address tokenTo, uint256 priceScaled) external onlyOwner {
        require(tokenFrom != address(0) && tokenTo != address(0), "zero token");
        require(priceScaled > 0, "price zero");
        price[tokenFrom][tokenTo] = priceScaled;
        emit PriceSet(tokenFrom, tokenTo, priceScaled);
    }

    // Swap tokenFrom for tokenTo at set price.
    // User must approve `amountFrom` of tokenFrom to this contract.
    function swap(address tokenFrom, address tokenTo, uint256 amountFrom, uint256 minAmountTo) external nonReentrant {
        require(amountFrom > 0, "amount 0");
        uint256 p = price[tokenFrom][tokenTo];
        require(p > 0, "price not set");

        // calculate amountTo = amountFrom * p / SCALE
        uint256 amountTo = (amountFrom * p) / SCALE;
        require(amountTo >= minAmountTo, "slippage");

        IERC20 from = IERC20(tokenFrom);
        IERC20 to = IERC20(tokenTo);

        // transfer tokenFrom from user to contract
        require(from.transferFrom(msg.sender, address(this), amountFrom), "transferFrom failed");

        // ensure contract has enough tokenTo reserve
        uint256 reserve = to.balanceOf(address(this));
        require(reserve >= amountTo, "insufficient reserve");

        // transfer tokenTo to user
        require(to.transfer(msg.sender, amountTo), "transfer failed");

        emit Swapped(msg.sender, tokenFrom, tokenTo, amountFrom, amountTo);
    }

    // Owner can withdraw tokens (for liquidity management)
    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    // helper to view price scaled
    function getPrice(address tokenFrom, address tokenTo) external view returns (uint256) {
        return price[tokenFrom][tokenTo];
    }
}
