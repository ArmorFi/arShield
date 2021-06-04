// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IController {
    function bonus() external view returns (uint256);
    function governor() external view returns (address);
    function depositAmt() external view returns (uint256);
}