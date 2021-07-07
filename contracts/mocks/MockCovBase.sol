// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

/**
 * @dev Mock Yearn Oracle to test arShields.
**/
contract MockCovBase {

    uint256 owed;
    bool allowed;

    constructor(
        address _controller
    )
    {}

    function getShieldOwed(
        address _shield
    )
      external
      view
    returns(
        uint256 ethOwed
    )
    {
        ethOwed = owed;
        _shield;
    }

    function changeEthOwed(
        uint256 _newOwed
    )
      external
    {
        owed = _newOwed;
    }

    function checkCoverage(
        uint256 _ethValue
    )
      external
      view
    returns(
        bool
    )
    {
        _ethValue;
        return allowed;
    }

    function changeAllowed(
        bool _newAllowed
    )
      external
    {
        allowed = _newAllowed;
    }

    function editShield(
        address _proxy,
        bool _thing
    )
      external
      pure
    {
        _proxy;
        _thing;
    }

    function updateShield(
        uint256 _ethValue
    )
      external
      payable
    {
        _ethValue;
    }

}