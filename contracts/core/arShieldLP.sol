// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import './PoolFuncs.sol';
import './RewardManager.sol';
import '../interfaces/IArmorMaster.sol';
import '../interfaces/IPlanManager.sol';
import '../interfaces/IClaimManager.sol';
import '../interfaces/IBalanceManager.sol';

/**
 * @title Armor Shield LP
 * @dev Vault to allow LPs to gain LP rewards and ARMOR tokens while being protected from hacks with coverage for the protocol.
 * @author Robert M.C. Forster
**/
contract ArShieldLP is Ownable, RewardManager, PoolFuncs {

    // The protocol that this contract buys coverage for (Nexus Mutual address for Uniswap/Balancer/etc.).
    address public protocol;
    
    // arCore manager contracts.
    IArmorMaster public armorMaster;
    IBalanceManager public balanceManager;
    IClaimManager public claimManager;
    IPlanManager public planManager;
    
    // Avoid composability issues for liquidation.
    modifier notContract {
        require(msg.sender == tx.origin, "Sender must be an EOA.");
        _;
    }
    
    modifier checkCoverage(uint256 amount) {
        uint256 available = allowedCoverage(tokenPrice * 1e18 / amount);
        require(available >= amount, "Not enough coverage available for this stake.");
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
        address _lpToken,
        address _rewardToken, 
        uint256 _feePerSec,
        uint256 _referPercent,
        address _protocol,
        uint256 _lpStartingPrice
    )
      public
    {
        //TODO: intialize armor master
        initializeOwnable();
        rewardInitialize(_rewardToken, _lpToken, msg.sender, _feePerSec, _referPercent);
        ammInitialize(_uniRouter, _lpToken, _baseTokens, _path0, _path1);
        armorMaster = IArmorMaster(_armorMaster);
        protocol = _protocol;

        // Stack too deep...
        tokenPrice = _lpStartingPrice;
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
        uint256 fullCoverage = totalSupply() / feePool * newBalance;
        
        // Save the individual token price. 1e18 needed for decimals.
        tokenPrice = fullCoverage * 1e18 / totalSupply();
        
        // Reset fee pool.
        feePool = 0;
        
        addBalance();
        updateCoverage( allowedCoverage(fullCoverage) );
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
        address[] memory protocols = new address[](1);
        protocols[0] = protocol;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        planManager.updatePlan(protocols, amounts);
    }

    function stake(uint256 amount, address _referrer) public override checkCoverage(amount) {
        RewardManager.stake(amount,_referrer);
    }
    /**
     * @dev Checks how much coverage is allowed on the contract. Buys as much as possible.
     *      Needed on this contract so we don't accept more funds than available as coverage.
     * @param _fullCoverage The full amount of coverage we want.
     * @return Amount of cover able to be purchased.
    **/
    function allowedCoverage(uint256 _fullCoverage)
      internal
      view
    returns (uint256)
    {
        uint256 available = planManager.coverageLeft(protocol);
        return available >= _fullCoverage ? _fullCoverage : available;
    }
    
    /**
     * @dev Claim coverage from arCore if a hack has occurred. Calls Claim Manager on arCore.
     * @param _hackTime Time that the hack occurred.
     * @param _amount Amount that this contract had covered at the time.
    **/
    function claimCoverage(uint256 _hackTime, uint256 _amount)
      external
    {
        // There shouldn't ever be an Ether balance in here but just in case there is...
        uint256 startBalance = address(this).balance;
        
        claimManager.redeemClaim(protocol, _hackTime, _amount);
        
        if (address(this).balance > startBalance) {
            weiPerToken = address(this).balance * 1e18 / totalSupply();
        }
    }
    
    /**
     * @dev Owner can withdraw balance from arCore if there is more than needed.
     * @param _amount The amount of Ether (in Wei) to withdraw from the arCore contract.
     *      Do we want this to withdraw to here then allow users to withdraw?
    **/
    function withdrawBalance(uint256 _amount)
      external
      onlyOwner
    {
        balanceManager.withdraw(_amount);
        owner().transfer(address(this).balance);
    }

    /**
     * @dev Unwrap LP token on Uniswap.
     * @param _amount The amount of tokens to be unwrapped.
    **/
    function unwrapLP(uint256 _amount)
      internal
      override
    {
        IUniPool(address(lpToken)).burn(_amount);
    }
}
