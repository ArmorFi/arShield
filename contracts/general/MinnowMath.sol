// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

library MinnowMath {
    /// @dev returns start * ( (denom + a)/denom)**n
    function calcPositiveCompoundInterest(uint256 start, uint256 a, uint256 denom, uint256 n) internal pure returns(uint256 result) {
        require(denom != 0, "div by 0");
        if(n == 0){
            return start;
        }
        result = start;
        uint256 base = denom;
        while (n > 1) {
            // result = result * a & base = base * denom until it overflows
            if(result*(denom+a) > result && base < base * denom ) {
                result *= (denom + a);
                base *= denom;
            } else {
                if(result < base) {
                    // this means result will be smaller than 0 so we stop here
                    return 0;
                } else {
                    result /= base;
                    result *= (denom + a);
                    base = denom;
                }
            }
            n--;
        }
        result /= base;
    }
}
