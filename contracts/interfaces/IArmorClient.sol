// SPDX-License-Identifier: (c) Armor.Fi DAO, 2021

pragma solidity 0.8.4;

interface IArmorClient {
    function submitProofOfLoss(uint256[] calldata _ids) external;
}
