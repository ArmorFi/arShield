// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IYearn {
    function pricePerShare() external view returns (uint256);
    function decimals() external view returns(uint256);
    function token() external view returns(address);
}
