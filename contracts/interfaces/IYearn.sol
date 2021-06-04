// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IYearn {
    function getPricePerFullShare() external view returns (uint256);
}