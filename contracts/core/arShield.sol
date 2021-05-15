pragma solidity ^0.6.6;

import '../general/SafeMath.sol';
import '../general/ArmorModule.sol';
import '../interfaces/IyDAI.sol';
import '../interfaces/IArmorMaster.sol';
import '../interfaces/IPlanManager.sol';
import '../interfaces/IClaimManager.sol';
import '../interfaces/IBalanceManager.sol';
import '../client/ArmorClient.sol';

/**
 * @title Armor Shield Yearn
 * @dev arShield accepts Yearn tokens, returns arTokens, those tokens are automatically insured.  
 * @author Armor.Fi -- Robert M.C. Forster
**/
contract ArShieldYearn is ArmorClient {

    using SafeMath for uint;

    // Buffer amount for division.
    uint256 constant private BUFFER = 1e18;
    
    // The protocol that this contract buys coverage for (Nexus Mutual address for Uniswap/Balancer/etc.).
    address[] public protocols;
    
    // If the Yearn vault is a Curve token, we must unwrap before selling.
    bool public crvToken;
    
    uint256 public vaultValue;
    
    // Beneficiary may withdraw any extra Ether after a claims period.
    address payable public beneficiary;
    
    // Whether or not the contract is locked.
    bool public locked;
    
    // Block at which users must be holding tokens to receive a payout.
    uint256 public payoutBlock;
    
    uint256 public depositReward;
    uint256 public depositAmount;
    address public depositor;
    
    // Delay (in seconds) between mint request and actual minting.
    uint256 public mintDelay;
    
    // 0.25% paid for minting in order to pay for the first week of coverage--can be immediately liquidated.
    uint256 public mintFees;
    
    // Last time an EOA has called this contract.
    mapping (address => uint256) public lastCall;
    
    // User => timestamp of when minting was requested.
    mapping (address => MintRequest) public mintRequests;


    // Protocol token that we're providing protection for.
    IyDAI public pToken;
    // Underlying token of the pToken.
    IERC20 public uToken;


    // Time and amount a user would like to mint.
    struct MintRequest {
        uint48 requestTime;
        uint208 requestAmount;
    }


    // event mint requestAmount
    // event mint finalize
    // event redeem

    modifier locked {
        require(locked, "You may not do this while the contract is unlocked.");
        _;
    }

    // Only allow minting when there are no claims processing (people withdrawing to receive Ether).
    modifier notLocked {
        require(!locked, "You may not do this while the contract is locked.");
        _;
    }

    // Avoid composability issues for liquidation.
    modifier notContract {
        require(msg.sender == tx.origin, "Sender must be an EOA.");
        _;
    }
    
    // Must be able to receive Ether from the arCore claim manager.
    receive() external payable { }
    
    /**
     * @dev Initialize the contract
     * @param _master Address of the Armor master contract.
     * @param _pToken The protocol token we're protecting.
    **/
    function initialize(address _pToken, address _uToken, address _uniPool, address _master, bool _crvToken)
      external
    {
        IArmorMaster(_master).initialize();
        pToken = IyDAI(_pToken);
        uToken = IERC20(_uToken);
        crvToken = _crvToken;
    }

    /**
     * @dev User deposits pToken, is returned arToken. Amount returned is judged based off amount in contract.
     *      Amount returned will likely be more than deposited because pTokens will be removed to pay for cover.
     * @param _pAmount Amount of pTokens to deposit to the contract.
    **/
    function mint(uint256 _pAmount, address _beneficiary)
      external
      notLocked
    {
        MintRequest memory mintRequest = mintRequests[_beneficiary];
        if (block.timestamp.sub(mintDelay) > mintRequest.requestTime) {
            delete mintRequests[_beneficiary];
            _mint(_beneficiary, mintRequest.requestAmount);
        } else if (mintRequest.requestTime == 0) {
            uint256 arAmount = arValue(_pAmount);
            pToken.transferFrom(_beneficiary, address(this), _pAmount);
            mintRequests[_beneficiary] = MintRequest(block.timestamp, arAmount);
        }
    }

    function redeem(uint256 _arAmount)
      external
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
        // Figure out how much value we have on contract
        // Tell CoverageBase how much value we have and ask how much we need to pay
        // Liquidate the amount we need to pay
        // Deposit into coverageBase

        _liquidate(addition);
        ArmorCore.deposit(addition);

        msg.sender.transfer(topUpReward);
    }
    
    /**
     * @dev Here we determine needed value of pToken, redeem tokens for value, exchange for Ether.
     * @param _refillNeeded Amount of Ether we need to liquidate tokens for.
    **/
    function _liquidate(uint256 _refillNeeded)
      internal
    {
    
        uint256 ethPerToken = _findEthPerToken;
        
    }

    /**
     * @dev Finds the amount of cover required to protect all holdings and returns Ether value of 1 token.
     * @return ethPerToken Ether value of each pToken.
    **/
    function _findEthPerToken()
      internal
    returns (uint256 ethPerToken)
    {
        uint256 uTokenPerPToken = pToken.getPricePerFullShare();
        ethPerToken = uniswap.tokenToEther(uTokenPerPToken);       
    }

    /**
     * @dev If the contract was locked because of a hack, it may be unlocked 1 month later.
    **/
    function unlock()
      external
      locked
    {
        require(block.timestamp.sub(lockPeriod) > lockTime, "You may not unlock until the total lock period has passed.")
        locked = false;
        lockTime = 0;
    }

    /**
     * @dev Funds may be withdrawn to beneficiary if any are leftover after a hack.
     * TODO: Add ability to withdraw tokens other than arToken
    **/
    function withdrawExcess()
      external
      notLocked
    {
        beneficiary.transfer(address(this).balance);
    }

    /**
     * @dev Anyone may call this to pause contract deposits for a couple days.
     *      They will get refunded + more when hack is confirmed.
    **/
    function notifyHack()
      external
      payable
      notLocked
    {
        require(msg.value == depositAmount, "You must pay the deposit amount to notify a hack.");
        depositor = msg.sender;
        locked = true;
        lockTime = block.timestamp;
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
        uint256 bufferedP = pToken.balanceOf( address(this) ).mul(1e18);
        uint256 bufferedAmount = totalSupply().div(bufferedP).mul(_pAmount);
        arAmount = bufferedAmount.div(1e18);
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
        uint256 bufferedAmount = bufferedP.div( totalSupply() ).mul(_arAmount);
        pAmount = bufferedAmount.div(1e18);
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
     * @dev Used by controller to confirm that a hack happened, which then locks the contract in anticipation of claims.
    **/
    function confirmHack(uint256 _payoutBlock)
      external
      onlyController
    {
        depositor.transfer(depositReward);
        delete depositor;
        payoutBlock = _payoutBlock;
    }
    
    /**
     * @dev Used by controller to confirm that a hack happened, which then locks the contract in anticipation of claims.
    **/
    function unlock()
      external
      onlyController
    {
        locked = false;
        lockTime = 0;
    }
    
    /**
     * @dev Controller can change different delay periods on the contract.
    **/
    function changeDelays(uint256 _mintDelay)
      external
      onlyController
    {
        mintDelay = _mintDelay;
    }

}
