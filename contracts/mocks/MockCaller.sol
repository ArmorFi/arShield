// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

contract MockCaller {
    function execute(address recipient,string calldata sig, bytes calldata data) external payable {
        bytes4 selector = bytes4(keccak256(abi.encodePacked(sig)));
        bytes memory populated = abi.encodePacked(selector, data);
        (bool success, bytes memory result) = recipient.call{value: msg.value}(populated);
        require(success);
    }
}
