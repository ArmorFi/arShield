// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IController {
    function bonus() external view returns (uint256);
    function depositAmt() external view returns (uint256);
}