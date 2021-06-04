// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface ICovBase {
    function editShield(address shield, bool active) external;
    function updateShield(uint256 ethValue) external payable;
    function getOwed(address shield) external view returns (uint256);
}