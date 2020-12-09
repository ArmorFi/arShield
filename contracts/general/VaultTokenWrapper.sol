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

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public virtual {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakeToken.safeTransfer(msg.sender, amount);
    }
    
    /**
     * @dev Only used by contract to update a user's balance by subtracting then adding to fee pool.
    **/
    function _updateStake(address _user, uint256 _amount)
      internal
    {
        _balances[_user] = _balances[_user].sub(_amount);
        feePool = feePool.add(_amount);

        // Even though these tokens are just moved to fee pool, total supply must lower so rewards distribute correctly.
        _totalSupply = _totalSupply.sub(_amount);
    }
}