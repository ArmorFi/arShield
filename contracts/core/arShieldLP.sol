// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import './PoolFuncs.sol';
import './RewardManagerWithReferral.sol';
import '../interfaces/IArmorMaster.sol';
import '../interfaces/IPlanManager.sol';
import '../interfaces/IClaimManager.sol';
import '../interfaces/IBalanceManager.sol';
/**
 * @title Armor Shield LP
 * @dev Vault to allow LPs to gain LP rewards and ARMOR tokens while being protected from hacks with coverage for the protocol.
 * @author Robert M.C. Forster
**/
contract ArShieldLP is Ownable, RewardManagerWithReferral, PoolFuncs {

    // The protocol that this contract buys coverage for (Nexus Mutual address for Uniswap/Balancer/etc.).
    address public protocol;
    
    // arCore manager contracts.
    IArmorMaster public armorMaster;
    
    // Price--in Ether--of each token.
    uint256 public tokenPrice;
    
    // Number of full Ether per full token. Only set if a claim is successful.
    uint256 public weiPerToken;
    
    modifier notLocked {
        require(weiPerToken == 0, "A claim has been made successfully.");
        _;
    }

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
        rewardInitialize(_rewardToken, _lpToken, msg.sender, _feePerSec, _referPercent);
        ammInitialize(_uniRouter, _lpToken, _baseTokens, _path0, _path1);
        armorMaster = IArmorMaster(_armorMaster);
        protocol = _protocol;
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
        require(newBalance > 0, "no ether to liquidate");
        // Do we need to make sure total supply is bigger than fee pool?
        uint256 fullCoverage = totalSupply() ;// / feePool * newBalance;
        // Save the individual token price. 1e18 needed for decimals.
        tokenPrice = fullCoverage * 1e18 / totalSupply();
        
        // Reset fee pool.
        feePool = 0;
        
        addBalance();
        updateCoverage(allowedCoverage(fullCoverage));
    }
    
    /**
     * @dev Add all Ether balance to the arCore account of this contract.
    **/
    function addBalance()
      internal
    {
        IBalanceManager(armorMaster.getModule("BALANCE")).deposit{value: address(this).balance}( address(0) );
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
        IPlanManager(armorMaster.getModule("PLAN")).updatePlan(protocols, amounts);
    }
    
    function endCoverage()
      internal
    {
        address[] memory protocols = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        IPlanManager(armorMaster.getModule("PLAN")).updatePlan(protocols, amounts);
    }

    function stake(uint256 amount, address _referrer) public override notLocked checkCoverage(amount) {
        RewardManagerWithReferral.stake(amount,_referrer);
    }

    function withdraw(uint256 amount) external override updateBalance(msg.sender) updateReward(msg.sender){
        require(amount > 0, "Cannot withdraw 0");
        RewardManagerWithReferral._withdraw(msg.sender, amount);
        // If a claim has been successful, also withdraw Ether.
        if (weiPerToken > 0) {
            // Amount is in token Wei while weiPerToken is per full token so 1e18 is needed.
            uint256 claimAmount = amount * weiPerToken / 1e18;
            msg.sender.transfer(claimAmount);
        }
    }

    function exit() external override updateBalance(msg.sender) updateReward(msg.sender){
        uint256 amount = balanceOf(msg.sender);
        RewardManagerWithReferral._withdraw(msg.sender, amount);
        getReward();
        // If a claim has been successful, also withdraw Ether.
        if (weiPerToken > 0) {
            // Amount is in token Wei while weiPerToken is per full token so 1e18 is needed.
            uint256 claimAmount = amount * weiPerToken / 1e18;
            msg.sender.transfer(claimAmount);
        }
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
        uint256 available = IPlanManager(armorMaster.getModule("PLAN")).coverageLeft(protocol);
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
        endCoverage();
        // There shouldn't ever be an Ether balance in here but just in case there is...
        uint256 startBalance = address(this).balance;
        
        IClaimManager(armorMaster.getModule("CLAIM")).redeemClaim(protocol, _hackTime, _amount);
        
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
        IBalanceManager(armorMaster.getModule("BALANCE")).withdraw(_amount);
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
        if(_amount > 0){
            uniRouter.removeLiquidity(address(baseToken0), address(baseToken1), _amount, 1, 1, address(this), uint256(-1));
        }
    }
}
