// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface IShieldController {
    function bonus() external view returns(uint256);
    function gov() external view returns(address);
}
