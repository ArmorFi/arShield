// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@umb-network/toolbox/dist/contracts/lib/ValueDecoder.sol";

/**
 * @dev Mock Umbrella Oracle to test arShields.
 **/
contract MockUmbrella {
    using ValueDecoder for bytes;

    // Mock can change this to check different scenarios.
    uint256 public tokensOwed;
    uint256 public ethOwed;

    function getTokensOwed(
        uint256 _ethOwed,
        bytes32 _yKey,
        bytes32[] calldata _tokenProof,
        bytes calldata _tokenValue
    ) external view returns (uint256 yOwed) {
        yOwed = tokensOwed;
    }

    function getEthOwed(
        uint256 _tokensOwed,
        bytes32 _yKey,
        bytes32[] calldata _tokenProof,
        bytes calldata _tokenValue
    ) external view returns (uint256) {
        return ethOwed;
    }

    function changeTokensOwed(uint256 _newOwed) external {
        tokensOwed = _newOwed;
    }

    function changeEthOwed(uint256 _newOwed) external {
        ethOwed = _newOwed;
    }
}
