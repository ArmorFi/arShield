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
abstract contract PoolFuncs {

    // UniSwap router that all Uni transactions are done through,
    // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D on Mainnet.
    IUniRouter public uniRouter;

    IERC20 public lpToken;
    // address(0) if Ether.
    IERC20 public baseToken0;
    IERC20 public baseToken1;

    // Uniswap paths for base tokens.
    address[] path0;
    address[] path1;

    function ammInitialize(address _uniRouter, address _lpToken, address[] memory _baseTokens, address[] memory _path0, address[] memory _path1)
      internal
    {
        lpToken = IERC20(_lpToken);
        baseToken0 = IERC20(_baseTokens[0]);
        baseToken1 = IERC20(_baseTokens[1]);
        
        uniRouter = IUniRouter(_uniRouter);
        
        require(_baseTokens[0] != _baseTokens[1], "Should have 2 base tokens");
        // this will prevent from reverting when base == ETH
        // actually, this should not happen since ETH is not being used as lp token base in uni/balancer
        //if(address(baseToken0) != address(0)){
        baseToken0.approve( address(uniRouter), uint256(-1) );
        //}
        //if(address(baseToken1) != address(0)){
        baseToken1.approve( address(uniRouter), uint256(-1) );
        //}

        // path verification would be nice
        path0 = _path0;
        path1 = _path1;
    }

    function unwrapLP(uint256 _amount) internal virtual;
    
    /**
     * @dev Sells all of this token on the contract through Uniswap.
    **/
    function sellTokens()
      internal
    {
        // Deadline of 1e18 is 
        uint256 balance0 = baseToken0.balanceOf( address(this) );
        uniRouter.swapExactTokensForEth( balance0, 0, path0, address(this), uint256(-1) );
        uint256 balance1 = baseToken1.balanceOf( address(this) );
        uniRouter.swapExactTokensForEth( balance1, 0, path1, address(this), uint256(-1) );
    }
}
