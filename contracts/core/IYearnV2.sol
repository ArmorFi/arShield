// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IYearnV2 {
    function decimals() external view returns(uint256);
    function pricePerShare() external view returns(uint256);
}
