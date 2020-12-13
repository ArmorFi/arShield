// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

interface IUniRouter {
    function removeLiquidity(address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline) external;
    function swapExactTokensForEth(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external;
}

interface IUniPool {
    function burn(uint256 amount) external returns(uint256 token0, uint256 token1);
}
