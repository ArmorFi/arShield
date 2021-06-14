// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

/**
 * @dev Mock Yearn Oracle to test arShields.
**/
contract MockCore {

    uint256 owed;
    bool allowed;

    function deposit(
        uint256 _amount
    )
      external
      payable
    {
        _amount;
    }

    function subscribe(
        address _protocol,
        uint256 _amount
    )
      external
    {
        _protocol;
        _amount;
    }

    function calculatePricePerSec(
        address _protocol,
        uint256 _amount
    )
      external
      view
    returns(
        uint256 pricePerSec
    )
    {
        pricePerSec = 1000000;
    }

}