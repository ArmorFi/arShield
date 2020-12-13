// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

interface IBalPool {
    function exitPool(uint poolAmountIn, uint[] calldata minAmountsOut) external;
}