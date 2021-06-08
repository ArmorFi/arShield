// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

/**
 * @dev Mock Yearn Oracle to test arShields.
**/
contract MockYearn {

    // Mock can change this to check different scenarios.
    uint256 public owed;

    function getTokensOwed(
        uint256 _ethOwed,
        address _pToken,
        address _uTokenLink
    )
      external
      view
    returns(
        uint256 tokensOwed
    )
    {
        tokensOwed = owed;
        _ethOwed;
        _pToken;
        _uTokenLink;
    }

    function changeOwed(
        uint256 _newOwed
    )
      external
    {
        owed = _newOwed;
    }

}