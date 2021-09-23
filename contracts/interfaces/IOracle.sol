// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IOracle {
    function getTokensOwed(
        uint256 _ethOwed,
        bytes32 _pKey,
        uint32 _blockId,
        bytes32[] calldata _tokenProof,
        bytes calldata _tokenValue
    ) external view returns (uint256);

    function getEthOwed(
        uint256 _tokensOwed,
        bytes32 _pKey,
        uint32 _blockId,
        bytes32[] calldata _tokenProof,
        bytes calldata _tokenValue
    ) external view returns (uint256);
}
