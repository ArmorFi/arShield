pragma solidity 0.6.12;
import '../general/SafeMath.sol';
import '../interfaces/IyDAI.sol';

/**
 * @title Armor Shield Base
 * @dev arShield base provides the base functionality of arShield contracts. It does not provide liquidation strategies
 * @author Armor.Fi -- Robert M.C. Forster
**/
contract arShieldBase {

    using SafeMath for uint;

    // Buffer amount for division.
    uint256 constant private BUFFER = 1e18;
    // Whether or not the contract is locked.
    bool public locked;
    // Beneficiary may withdraw any extra Ether after a claims period.
    address payable public beneficiary;
    // Block at which users must be holding tokens to receive a payout.
    uint256 public payoutBlock;
    // Amount of Ether given to user who notified of a hack.
    uint256 public depositReward;
    // Amount of Ether required to notify of a hack and temporarily lock contract.
    uint256 public depositAmount;
    // User who deposited to notify of a hack.
    address public depositor;
    // Delay (in seconds) between mint request and actual minting.
    uint256 public mintDelay;
    // 0.25% paid for minting in order to pay for the first week of coverage--can be immediately liquidated.
    uint256 public mintFees;
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

    event MintRequest(address indexed user, uint256 amount, uint256 timestamp);
    event MintFinalized(address indexed user, uint256 amount, uint256 timestamp);
    event Redemption(address indexed user, uint256 amount, uint256 timestamp);
    event Locked(address reporter, uint256 timestamp);
    event Unlocked(uint256 timestamp);
    event HackConfirmed(uint256 payoutBlock, uint256 timestamp);

    modifier locked {
        require(locked, "You may not do this while the contract is unlocked.");
        _;
    }

    // Only allow minting when there are no claims processing (people withdrawing to receive Ether).
    modifier notLocked {
        require(!locked, "You may not do this while the contract is locked.");
        _;
    }
    
    receive() external payable;
    
    /**
     * @dev Initialize the contract
     * @param _master Address of the Armor master contract.
     * @param _pToken The protocol token we're protecting.
    **/
    function initialize(
        address _pToken, 
        address _uToken, 
        address _uniPool, 
        address _master, 
        bool _crvToken
    )
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
    function mint(
        uint256 _pAmount, 
        address _beneficiary
    )
      external
      notLocked
    {
        MintRequest memory mintRequest = mintRequests[_beneficiary];
        
        if (mintRequest.requestTime == 0) {
            
            uint256 arAmount = arValue(_pAmount);
            pToken.transferFrom(_beneficiary, address(this), _pAmount);
            mintRequests[_beneficiary] = MintRequest(block.timestamp, arAmount);
            emit MintRequest(_beneficiary, arAmount, block.timestamp);
            
        } else if (block.timestamp.sub(mintDelay) > mintRequest.requestTime) {
            
            delete mintRequests[_beneficiary];
            _mint(_beneficiary, mintRequest.requestAmount);
            emit MintFinalized(_beneficiary, mintRequest.requestAmount, block.timestamp);
        
        }
    }

    function redeem(
        uint256 _arAmount
    )
      external
    {
        uint256 pAmount = pValue(_arAmount);
        _burn(msg.sender, _arAmount);
        arToken.transfer(msg.sender, pAmount);
        if (locked() && address(this).balance > 0) _sendClaim(_pAmount);
        emit Redemption(msg.sender, _arAmount, block.timestamp);
    }

    /**
     * @dev Funds may be withdrawn to beneficiary if any are leftover after a hack.
     * TODO: Add ability to withdraw tokens other than arToken
    **/
    function withdrawExcess()
      external
      notLocked
    {
        beneficiary.transfer( address(this).balance );
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
        emit Locked(msg.sender, block.timestamp);
    }

    /**
     * @dev Find the arToken value of a pToken amount.
     * @param _pAmount Amount of yTokens to find arToken value of.
     * @return arAmount Amount of arToken the input pTokens are worth.
    **/
    function arValue(
        uint256 _pAmount
    )
      public
      view
    returns (
        uint256 arAmount
    )
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
    function pValue(
        uint256 _arAmount
    )
      public
      view
    returns (
        uint256 pAmount
    )
    {
        uint256 bufferedP = pToken.balanceOf( address(this) ) * 1e18;
        uint256 bufferedAmount = bufferedP.div( totalSupply() ).mul(_arAmount);
        pAmount = bufferedAmount.div(1e18);
    }

    /**
     * @dev Sends Ether if the contract is locked and Ether is in it.
    **/
    function _sendEther(
        uint256 _arAmount
    )
      internal
    {
        uint256 ethAmount = _arAmount * BUFFER / totalSupply() * address(this).balance / BUFFER;
        msg.sender.transfer(ethAmount);
    }
    
    /**
     * @dev Used by controller to confirm that a hack happened, which then locks the contract in anticipation of claims.
    **/
    function confirmHack(
        uint256 _payoutBlock
    )
      external
      onlyController
    {
        // TODO: change to safe transfer
        depositor.transfer(depositReward);
        delete depositor;
        payoutBlock = _payoutBlock;
        emit HackConfirmed(_payoutBlock, block.timestamp);
    }
    
    /**
     * @dev Used by controller to confirm that a hack happened, which then locks the contract in anticipation of claims.
    **/
    function unlock()
      external
      locked
      onlyController
    {
        locked = false;
        lockTime = 0;
        emit Unlocked(block.timestamp);
    }
    
    /**
     * @dev Controller can change different delay periods on the contract.
    **/
    function changeDelays(
        uint256 _mintDelay
    )
      external
      onlyController
    {
        mintDelay = _mintDelay;
    }

}
