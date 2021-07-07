// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IArmorClient {
    function submitProofOfLoss(uint256[] calldata _ids) external;
}
