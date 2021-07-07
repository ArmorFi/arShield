// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IArmorMaster {
    function registerModule(bytes32 _key, address _module) external;
    function getModule(bytes32 _key) external view returns(address);
    function keep() external;
}
