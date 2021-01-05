// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import '../general/SafeERC20.sol';
import '../libraries/SafeMath.sol';
contract VaultTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public stakeToken;

    // Amount of tokens currently in the fee pool.
    uint256 public feePool;
    uint256 private _totalSupply;
    
    mapping(address => uint256) private _balances;
    
    // Armor is adding this to avoid too many balances updates in one call. Referrer funds do not gain rewards.
    mapping (address => uint256) public referralBalances;

    function initializeVaultTokenWrapper(address _token) internal {
        stakeToken = IERC20(_token);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }


    // changed to internal to not be used in external situation
    function _stake(uint256 amount) internal {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    // changed to internal to not be used in external situation
    // this could have stayed public since withdraw is being overrided
    // but changed to match the integrity
    function _withdraw(uint256 amount) internal {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakeToken.safeTransfer(msg.sender, amount);
    }
    
    /**
     * @dev Referral rewards withdrawn separately and have already been subtracted from total supply.
     * @param _amount Amount of referral rewards to withdraw.
    **/
    function withdrawReferral(uint256 _amount)
      external
    {
        // Throws on too high amount.
        referralBalances[msg.sender] = referralBalances[msg.sender].sub(_amount);
        stakeToken.safeTransfer(msg.sender, _amount);
    }
    
    /**
     * @dev Only used by contract to update a user's balance by subtracting then adding to fee pool.
    **/
    function _updateStake(address _user, address _referrer, uint256 _amount, uint256 _referAmount)
      internal
    {
        _balances[_user] = _balances[_user].sub( _amount.add(_referAmount) );
        referralBalances[_referrer] = referralBalances[_referrer].add(_referAmount);
        // Fee pool cannot include referral balance, but total supply must subtract.
        feePool = feePool.add(_amount);

        // Even though these tokens are just moved to fee pool, total supply must lower so rewards distribute correctly.
        _totalSupply = _totalSupply.sub( _amount.add(_referAmount) );
    }
}
