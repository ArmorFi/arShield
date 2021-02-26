// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import '../general/ArmorModule.sol';
import '../interfaces/IyDAI.sol';
import '../interfaces/IArmorMaster.sol';
import '../interfaces/IPlanManager.sol';
import '../interfaces/IClaimManager.sol';
import '../interfaces/IBalanceManager.sol';
/**
 * @title Armor Shield Yearn
 * @dev arShield accepts Yearn tokens, returns arTokens, those tokens are automatically insured.  
 * @author Armor.Fi -- Robert M.C. Forster
**/
contract ArShieldYearn is arERC20 {

    // Buffer amount for division.
    uint256 constant private BUFFER = 1e18;
    // The protocol that this contract buys coverage for (Nexus Mutual address for Uniswap/Balancer/etc.).
    address public protocol;
    // Price--in Ether--of each token.
    uint256 public tokenPrice;
    // Beneficiary may withdraw any extra Ether after a claims period.
    address public payable beneficiary;
    // Whether or not the contract is locked.
    bool public locked;
    // The time that a lock occurred.
    uint256 public lockTime;
    // Total lock period before minting is allowed again.
    uint256 public totalLockPeriod;
    // Last time an EOA has called this contract.
    mapping (address => uint256) public lastCall;
    // User => timestamp of when minting was requested.
    mapping (address => uint256) public mintRequest;

    IpToken public pToken;

    modifier locked {
        require(_locked(), "You may not do this while the contract is unlocked.");
    }

    // Only allow minting when there are no claims processing (people withdrawing to receive Ether).
    modifier notLocked {
        require(!_locked(), "You may not do this while the contract is locked.");
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
    
    // Functions as re-entrancy protection and more.
    // Mapping down below with other update variables.
    modifier oncePerTx {
        require(block.timestamp > lastCall[tx.origin], "May only call this contract once per transaction.");
        lastCall[tx.origin] = block.timestamp;
        _;
    }
    
    // Must be able to receive Ether from the arCore claim manager.
    receive() external payable { }
    
    /**
     * @dev Initialize the contract
     * @param _master Address of the Armor master contract.
     * @param _pToken The protocol token we're protecting.
    **/
    function initialize(address _pToken, address _master)
      external
    {
        IArmorMaster(_master).initialize();
        pToken = IpToken(_pToken);
    }

    /**
     * @dev User deposits pToken, is returned arToken. Amount returned is judged based off amount in contract.
     *      Amount returned will likely be more than deposited because pTokens will be removed to pay for cover.
     * @param _pAmount Amount of pTokens to deposit to the contract.
    **/
    function mint(uint256 _pAmount)
      external
      notLocked
      oncePerTx
    {
        uint256 arAmount = arValue(_pAmount);
        // TODO: separate into another function
        if (mintRequest[msg.sender] <= block.timestamp - mintDelay) {
            pToken.transferFrom(msg.sender, address(this), _pAmount);
            mintRequest = 0;
        } else if (mintRequest[msg.sender] == 0) {
            mintRequest[msg.sender] = block.timestamp;
        }
        _mint(msg.sender, arAmount);
    }
    
    function burn(uint256 _arAmount)
      external
      oncePerTx
    {
        uint256 pAmount = pValue(_arAmount);
        _burn(msg.sender, _arAmount);
        arToken.transfer(msg.sender, pAmount);
        if (locked() && address(this).balance > 0) _sendClaim(_pAmount);
    }
    
    /**
     * @dev Exchange pToken for the underlying token, sell on a dex, purchase insurance.
     *      We're not very concerned with price manipulation on dexes because there's little
     *      to no incentive for malicious actors and flash loans cannot be used.
    **/
    function liquidate()
      external
      notLocked
      notContract
    {
        uint256 pricePerToken = pToken.pricePerFullShare();
        uint256 fullCoverage = totalSupply() * pricePerToken / 1e18;
        // Find Ether price of full coverage for 1 month?
        pToken.withdraw()
        // Sell enough on Uniswap to cover full coverage       
        _addBalance();
        _updateCoverage(allowedCoverage(fullCoverage));
    }

    /**
     * @dev If the contract was locked because of a hack, it may be unlocked 1 month later.
    **/
    function unlock()
      external
      locked
    {
        require(lockTime <= block.timestamp - totalLockPeriod, "You may not unlock until the total lock period has passed.")
        locked = false;
        lockTime = 0;
    }

    /**
     * @dev Funds may be withdrawn to beneficiary if any are leftover after a hack.
    **/
    function withdrawExcess()
      external
      notLocked
    {
        beneficiary.transfer(address(this).balance);
    }

    /**
     * @dev Claim coverage from arCore if a hack has occurred. Calls Claim Manager on arCore.
     * @param _hackTime Time that the hack occurred.
     * @param _amount Amount that this contract had covered at the time.
    **/
    function redeemClaim(uint256 _hackTime, uint256 _amount)
      external
      locked
    {
        IClaimManager(armorMaster.getModule("CLAIM")).redeemClaim(protocol, _hackTime, _amount);
    }

    /**
     * @dev Find the arToken value of a pToken amount.
     * @param _pAmount Amount of yTokens to find arToken value of.
     * @return arAmount Amount of arToken the input pTokens are worth.
    **/
    function arValue(uint256 _pAmount)
      public
      view
    returns (uint256 arAmount)
    {
        uint256 bufferedP = pToken.balanceOf( address(this) ) * 1e18;
        uint256 bufferedAmount = totalSupply() / bufferedP * _pAmount;
        arAmount = bufferedAmount / 1e18;
    }
    
    /**
     * @dev Inverse of arValue (find yToken value of arToken amount).
     * @param _arAmount Amount of arTokens to find yToken value of.
     * @return pAmount Amount of pTokens the input arTokens are worth.
    **/
    function pValue(uint256 _arAmount)
      public
      view
    returns (uint256 pAmount)
    {
        uint256 bufferedP = pToken.balanceOf( address(this) ) * 1e18;
        uint256 bufferedAmount = bufferedP / totalSupply() * _arAmount;
        pAmount = bufferedAmount / 1e18;
    }

    /**
     * @dev Checks how much coverage is allowed on the contract. Buys as much as possible.
     *      Needed on this contract so we don't accept more funds than available as coverage.
     * @param _fullCoverage The full amount of coverage we want.
     * @return Amount of cover able to be purchased.
    **/
    function allowedCoverage(uint256 _fullCoverage)
      public
      view
    returns (uint256)
    {
        uint256 available = IPlanManager(armorMaster.getModule("PLAN")).coverageLeft(protocol);
        return available >= _fullCoverage ? _fullCoverage : available;
    }

    /**
     * @dev Sends Ether if the contract is locked and Ether is in it.
    **/
    function _sendEther(uint256 _arAmount)
      internal
    {
        uint256 ethAmount = _arAmount * BUFFER / totalSupply() * address(this).balance / BUFFER;
        msg.sender.transfer(ethAmount);
    }

    /**
     * @dev Add all Ether balance to the arCore account of this contract.
    **/
    function _addBalance()
      internal
    {
        IBalanceManager(armorMaster.getModule("BALANCE")).deposit{value: address(this).balance}( address(0) );
    }
    
    /**
     * @dev Update coverage amount on arCore for this contract.
     * @param _amount Amount of Ether in Wei to be covered.
    **/
    function _updateCoverage(uint256 _amount)
      internal
    {
        address[] memory protocols = new address[](1);
        protocols[0] = protocol;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        IPlanManager(armorMaster.getModule("PLAN")).updatePlan(protocols, amounts);
    }
    
    /**
     * @dev End coverage when a claim occurs.
    **/
    function _endCoverage()
      internal
    {
        address[] memory protocols = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        IPlanManager(armorMaster.getModule("PLAN")).updatePlan(protocols, amounts);
    }

    /**
     * @dev Used by owner to confirm that a hack happened, which then locks the contract in anticipation of claims.
    **/
    function confirmHack()
      external
      onlyOwner
    {
        locked = true;
        lockTime = block.timestamp;
    }

}
