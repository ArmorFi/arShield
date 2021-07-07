// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface ICovBase {
    function editShield(address shield, bool active) external;
    function updateShield(uint256 ethValue) external payable;
    function checkCoverage(uint256 pAmount) external view returns (bool);
    function getShieldOwed(address shield) external view returns (uint256);
}