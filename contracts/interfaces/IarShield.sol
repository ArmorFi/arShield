// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IarShield {
    function initialize(
        address _arToken,
        address _pToken,
        address _uTokenLink,
        address _oracle,
        address[] calldata _covBases,
        uint256[] calldata _fees
    ) external;
}
