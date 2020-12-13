// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import '../interfaces/IERC20.sol';
import '../interfaces/IUniPool.sol';
import '../interfaces/IBalPool.sol';

/**
 * @title Armor Vault
 * @dev Vault to allow LPs to gain LP rewards and ARMOR tokens while having insurance.
 *      This is the Uniswap version.
 * @author Robert M.C. Forster
**/
contract PoolFuncs {

    address constant UNISWAP = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant BALANCER = 0x9424B1412450D0f8Fc2255FAf6046b98213B76Bd;
    
    // UniSwap router that all Uni transactions are done through,
    // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D on Mainnet.
    IUniPool public uniRouter;

    IERC20 public lpToken;
    // address(0) if Ether.
    IERC20 public baseToken0;
    IERC20 public baseToken1;

    address public lpPool;

    // We're just hardcoding this 2 var dynamic array in for Balancer.
    uint256[] amounts;
    
    // Uniswap paths for base tokens.
    address[] path0;
    address[] path1;

    function ammInitialize(address _uniRouter, address _lpToken, address _lpPool, address[] memory _baseTokens, address[] memory _path0, address[] memory _path1)
      internal
    {
        lpToken = IERC20(_lpToken);
        baseToken0 = IERC20(_baseTokens[0]);
        baseToken1 = IERC20(_baseTokens[1]);
        
        lpPool = _lpPool;
        uniRouter = IUniPool(_uniRouter);
        
        lpToken.approve( address(lpPool), uint256(-1) );
        baseToken0.approve( address(uniRouter), uint256(-1) );
        baseToken1.approve( address(uniRouter), uint256(-1) );
        
        // lol
        amounts.push(0);
        amounts.push(0);
        
        path0 = _path0;
        path1 = _path1;
    }

    /**
     * @dev Unwrap LP token on Uniswap.
     * @param _amount The amount of tokens to be unwrapped.
    **/
    function uniUnwrapLP(uint256 _amount)
      internal
    {
        IUniPool(lpPool).removeLiquidity( address(baseToken0), address(baseToken1), _amount, 0, 0, address(this), uint256(-1) );
    }
    
    /**
     * @dev Unwrap LP token on Balancer.
     * @param _amount The amount of tokens to be unwrapped.
    **/
    function balUnwrapLP(uint256 _amount)
      internal
    {
        IBalPool(lpPool).exitPool(_amount, amounts);
    }
    
    /**
     * @dev Sells all of this token on the contract through Uniswap.
    **/
    function sellTokens()
      internal
    {
        // Deadline of 1e18 is 
        if ( address(baseToken0) != address(0) ) {
            uint256 balance0 = baseToken0.balanceOf( address(this) );
            uniRouter.swapExactTokensForEth( balance0, 0, path0, address(this), uint256(-1) );
        }
        
        if ( address(baseToken1) != address(0) ) {
            uint256 balance1 = baseToken1.balanceOf( address(this) );
            uniRouter.swapExactTokensForEth( balance1, 0, path1, address(this), uint256(-1) );
        }
    }

}