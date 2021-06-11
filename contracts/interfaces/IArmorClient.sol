// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IArmorClient {
    function submitProofOfLoss(uint256[] calldata _ids) external;
}
