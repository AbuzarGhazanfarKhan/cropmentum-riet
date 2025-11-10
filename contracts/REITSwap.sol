// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/*
  REITSwap
  - Integrated with Uniswap v3 router for AMM-based swaps.
  - Users call swap(tokenFrom, tokenTo, amountFrom, minAmountTo, fee) to swap via Uniswap.
  - Requires user to approve tokenFrom to this contract.
  - Reentrancy guarded.
  - NOTE: This is a sample integration; for production, handle multi-hop paths, slippage, and fees appropriately.
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

contract REITSwap is Ownable, ReentrancyGuard {
    ISwapRouter public immutable swapRouter;
    address public immutable WETH9; // Wrapped ETH for ETH swaps if needed

    event Swapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(address _swapRouter, address _weth9) {
        require(_swapRouter != address(0), "zero router");
        swapRouter = ISwapRouter(_swapRouter);
        WETH9 = _weth9;
    }

    // Swap tokenFrom for tokenTo via Uniswap v3.
    // User must approve `amountIn` of tokenFrom to this contract.
    // fee: pool fee tier (e.g., 3000 for 0.3%, 500 for 0.05%, 10000 for 1%)
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint24 fee
    ) external nonReentrant returns (uint256 amountOut) {
        require(amountIn > 0, "amountIn zero");
        require(tokenIn != address(0) && tokenOut != address(0), "zero token");

        IERC20 token = IERC20(tokenIn);

        // Transfer tokenIn from user to contract
        require(token.transferFrom(msg.sender, address(this), amountIn), "transferFrom failed");

        // Approve router to spend tokenIn
        token.approve(address(swapRouter), amountIn);

        // Prepare swap params
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: msg.sender, // Send directly to user
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Execute swap
        amountOut = swapRouter.exactInputSingle(params);

        emit Swapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    // Owner can withdraw any stuck tokens
    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
}
