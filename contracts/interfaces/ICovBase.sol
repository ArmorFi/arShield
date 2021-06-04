// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ICovBase {
    function addShield(address shield) external;
    function updateShield(uint256 ethValue) external payable;
    function getOwed(address shield) external view returns (uint256);
}