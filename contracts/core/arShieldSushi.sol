// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;
import '../interfaces/IMasterChef.sol';
import './arShieldLP.sol';
/**
 * @title Armor Shield LP - Sushi
 * @dev Vault to allow LPs to gain LP rewards and ARMOR tokens while being protected from hacks with coverage for the protocol.
 * @author Robert M.C. Forster
**/
contract ArShieldSushi is ArShieldLP {
    IMasterChef public masterChef;

    IERC20 public sushiToken;

    uint256 public pid;

    uint256 public sushiRewardRate;

    uint256 public sushiRewardPerTokenStored;

    mapping(address => uint256) public sushiRewards;

    mapping(address => uint256) public sushiUserRewardPerTokenPaid;

    event SushiRewardPaid(address account, uint256 reward);
    event SushiRewardAdded(uint256 reward);

    modifier updateReward(address account) override {
        // original rewards
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        // sushi rewards
        sushiRewardPerTokenStored = sushiRewardPerToken();
        if (account != address(0)) {
            sushiRewards[account] = sushiEarned(account);
            sushiUserRewardPerTokenPaid[account] = sushiRewardPerTokenStored;
        }
        _;
    }

    function sushiRewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return sushiRewardPerTokenStored;
        }
        return
            sushiRewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(sushiRewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function sushiEarned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(sushiRewardPerToken().sub(sushiUserRewardPerTokenPaid[account]))
                .div(1e18)
                .add(sushiRewards[account]);
    }
    
    function getReward() public override updateBalance(msg.sender) updateReward(msg.sender) {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
        
        //get Sushi reward
        uint256 sushiReward = sushiEarned(msg.sender);
        if (sushiReward > 0) {
            sushiRewards[msg.sender] = 0;
            sushiToken.safeTransfer(msg.sender, reward);
            emit SushiRewardPaid(msg.sender, reward);
        }
    }
    
    function notifyRewardAmount(uint256 reward)
        external
        payable
        override
        onlyRewardDistribution
        updateReward(address(0))
    {
        //this will make sure tokens are in the reward pool
        if ( address(rewardToken) == address(0) ) require(msg.value == reward, "Correct reward was not sent.");
        else rewardToken.safeTransferFrom(msg.sender, address(this), reward);
       
        if(reward > 0){ 
            if (block.timestamp >= periodFinish) {
                rewardRate = reward.div(DURATION);
            } else {
                uint256 remaining = periodFinish.sub(block.timestamp);
                uint256 leftover = remaining.mul(rewardRate);
                rewardRate = reward.add(leftover).div(DURATION);
            }
            emit RewardAdded(reward);
        }

        masterChef.withdraw(pid,0);
        uint256 sushiReward = sushiToken.balanceOf(address(this));
        if(sushiReward > 0){
            if (block.timestamp >= periodFinish) {
                sushiRewardRate = sushiReward.div(DURATION);
            } else {
                uint256 remaining = periodFinish.sub(block.timestamp);
                uint256 leftover = remaining.mul(sushiRewardRate);
                sushiRewardRate = sushiReward.add(leftover).div(DURATION);
            }
            emit SushiRewardAdded(sushiReward);
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(DURATION);
    }

    /**
     * @dev Setting reward manager, AMM, and vault variables.
     * @param _baseTokens The 2 base tokens of the LP token.
     * @param _path0 and _path1 set the Uniswap paths to exchange the token for Ether.
     * @param _uniRouter The main Uniswap router contract.
     * @param _pid The LP token we're farming/covering.
     * @param _rewardToken The token being rewarded (ARMOR).
     * @param _feePerSec The fee (in 18 decimal percent, i.e. 1% == 1e18) charged per second for coverage.
     * @param _protocol The address of the protocol (from Nexus Mutual) that we're buying coverage for.
    **/
    constructor(
        address[] memory _baseTokens, 
        address[] memory _path0,
        address[] memory _path1,
        address _armorMaster,
        address _uniRouter,
        uint256 _pid,
        address _rewardToken, 
        uint256 _feePerSec,
        uint256 _referPercent,
        address _protocol,
        uint256 _lpStartingPrice,
        address _masterChef
    ) ArShieldLP(_baseTokens, _path0, _path1, _armorMaster, _uniRouter, lpTokenAddress(_masterChef, _pid), _rewardToken, _feePerSec, _referPercent, _protocol, _lpStartingPrice)
      public
    {
        pid = _pid;
        masterChef = IMasterChef(_masterChef);
        sushiToken = IERC20(masterChef.sushi());
    }

    function lpTokenAddress(address _masterChef, uint256 _pid) public view returns(address) {
        (IERC20 lp, , ,) = IMasterChef(_masterChef).poolInfo(_pid);
        return address(lp);
    }
}
