pragma solidity ^0.6.6;

interface IUniPool {
    function removeLiquidity(address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline) external;
    function swapExactTokensForEth(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external;
}