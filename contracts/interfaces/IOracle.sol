// SPDX-License-Identifier: MIT

interface IOracle {
    function getTokensOwed(
        uint256 _ethOwed,
        address _yToken,
        address _uTokenLink
    ) external view returns(uint256);
}
