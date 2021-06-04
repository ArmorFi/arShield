// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IOracle {
    function getTokensOwed(uint256 ethOwed, address pToken, address uTokenLink) external view returns (uint256);
}