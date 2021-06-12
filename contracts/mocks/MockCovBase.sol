// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

/**
 * @dev Mock Yearn Oracle to test arShields.
**/
contract MockCovBase {

    uint256 owed;

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

}