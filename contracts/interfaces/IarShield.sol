// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IarShield {
    function initialize(
        address _oracle,
        address _pToken,
        address _arToken,
        address _uTokenLink,
        address payable _beneficiary,
        uint256[] calldata _fees,
        address[] calldata _covBases
    ) 
      external;
}