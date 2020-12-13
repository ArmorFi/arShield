// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

interface IClaimManager {
    function initialize(address _planManager, address _arNFT) external;
    function transferNft(address _to, uint256 _nftId) external;
    function redeemClaim(address _protocol, uint256 _hackTime, uint256 _amount, bytes32[] calldata _path) external;
}