// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import './PoolFuncs.sol';
import './RewardManager.sol';
import '../interfaces/IPlanManager.sol';
import '../interfaces/IClaimManager.sol';
import '../interfaces/IBalanceManager.sol';

/**
 * @title Armor Vault
 * @dev Vault to allow LPs to gain LP rewards and ARMOR tokens while being protected from hacks with coverage for the protocol.
 * @author Robert M.C. Forster
**/
contract ArVault is Ownable, RewardManager, PoolFuncs {

    // The protocol that this contract buys coverage for (Nexus Mutual address for Uniswap/Balancer/etc.).
    address public protocol;
    
    // Needed to update plan.
    address[] newProtocol;
    address[] oldProtocol;
    uint256[] newAmount;
    uint256[] oldAmount;
    
    // arCore manager contracts.
    IBalanceManager public balanceManager;
    IClaimManager public claimManager;
    IPlanManager public planManager;
    
    // Avoid composability issues for liquidation.
    modifier notContract {
        require(msg.sender == tx.origin, "Sender must be an EOA.");
        _;
    }
    
    // Must be able to receive Ether from the arCore claim manager.
    receive() external payable { }
    
    /**
     * @dev Setting reward manager, AMM, and vault variables.
     * @param _baseTokens The 2 base tokens of the LP token.
     * @param _path0 and _path1 set the Uniswap paths to exchange the token for Ether.
     * @param _uniRouter The main Uniswap router contract.
     * @param _lpToken The LP token we're farming/covering.
     * @param _lpPool Address of the pool to unwrap the LP token.
     * @param _rewardToken The token being rewarded (ARMOR).
     * @param _feePerSec The fee (in 18 decimal percent, i.e. 1% == 1e18) charged per second for coverage.
     * @param _balanceManager _claimManager and _planManager are addresses of the arCore contracts.
     * @param _protocol The address of the protocol (from Nexus Mutual) that we're buying coverage for.
    **/
    constructor(
        address[] memory _baseTokens, 
        address[] memory _path0,
        address[] memory _path1,
        address _uniRouter,
        address _lpToken,
        address _rewardToken, 
        uint256 _feePerSec, 
        address _balanceManager,
        address _claimManager,
        address _planManager,
        address _protocol
    )
      public
    {
        planManager = IPlanManager(_planManager);
        claimManager = IClaimManager(_claimManager);
        balanceManager = IBalanceManager(_balanceManager);
        rewardInitialize(_rewardToken, _lpToken, msg.sender, _feePerSec);
        ammInitialize(_uniRouter, _lpToken, _baseTokens, _path0, _path1);
        initializeVaultTokenWrapper(_lpToken);
        protocol = _protocol;

        newProtocol.push(_protocol);
    }
    
    /**
     * @dev Liquidate locked tokens to pay for coverage.
    **/
    function liquidate()
      external
      notContract
    {
        // There shouldn't ever be an Ether balance in here but just in case there is...
        uint256 balance = address(this).balance;
        
        // Unwrap then sell for Ether
        unwrapLP(feePool);
        sellTokens();
        
        uint256 newBalance = address(this).balance.sub(balance);
        // Do we need to make sure total supply is bigger than fee pool?
        uint256 coverage = totalSupply() / feePool * newBalance;
        
        addBalance();
        updateCoverage(coverage);
    }
    
    /**
     * @dev Add all Ether balance to the arCore account of this contract.
    **/
    function addBalance()
      internal
    {
        balanceManager.deposit{value: address(this).balance}( address(0) );
    }
    
    /**
     * @dev Update coverage amount on arCore for this contract.
     * @param _amount Amount of Ether in Wei to be covered.
    **/
    function updateCoverage(uint256 _amount)
      internal
    {
        newAmount[0] = _amount;
        planManager.updatePlan(oldProtocol, oldAmount, newProtocol, newAmount);
        if (oldAmount.length == 0) oldAmount.push(_amount);
        else oldAmount[0] = _amount;
        if (oldProtocol.length == 0) oldProtocol.push(protocol);
    }
    
    /**
     * @dev Claim coverage from arCore if a hack has occurred. Calls Claim Manager on arCore.
     * @param _hackTime Time that the hack occurred.
     * @param _amount Amount that this contract had covered at the time.
     * @param _path Merkle path for Plan Manager.
    **/
    function claimCoverage(uint256 _hackTime, uint256 _amount, bytes32[] calldata _path)
      external
    {
        // There shouldn't ever be an Ether balance in here but just in case there is...
        uint256 startBalance = address(this).balance;
        
        claimManager.redeemClaim(protocol, _hackTime, _amount, _path);
        
        if (address(this).balance > startBalance) {
            weiPerToken = address(this).balance * 1e18 / totalSupply();
        }
    }
    
    /**
     * @dev Owner can withdraw balance from arCore if there is more than needed.
     * @param _amount The amount of Ether (in Wei) to withdraw from the arCore contract.
    **/
    function withdrawBalance(uint256 _amount)
      external
      onlyOwner
    {
        balanceManager.withdraw(_amount);
        owner().transfer(address(this).balance);
    }
    
}
