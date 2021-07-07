// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

/**
 * @dev Mock Yearn Oracle to test arShields.
**/
contract MockYearn {

    // Mock can change this to check different scenarios.
    uint256 public tokensOwed;
    uint256 public ethOwed;

    function getTokensOwed(
        uint256 _ethOwed,
        address _pToken,
        address _uTokenLink
    )
      external
      view
    returns(
        uint256 owed
    )
    {
        owed = tokensOwed;
        _ethOwed;
        _pToken;
        _uTokenLink;
    }

    function getEthOwed(
        uint256 _tokensOwed,
        address _pToken,
        address _uTokenLink
    )
      external
      view
    returns(
        uint256 owed
    )
    {
        owed = ethOwed;
        _tokensOwed;
        _pToken;
        _uTokenLink;
    }

    function changeTokensOwed(
        uint256 _newOwed
    )
      external
    {
        tokensOwed = _newOwed;
    }

    function changeEthOwed(
        uint256 _newOwed
    )
      external
    {
        ethOwed = _newOwed;
    }

}