pragma solidity 0.6.12;
import '../general/SafeMath.sol';
import '../interfaces/IyDAI.sol';

/**
 * @title Armor Shield
 * @dev arShield base provides the base functionality of arShield contracts.
 * @author Armor.Fi -- Robert M.C. Forster
**/
contract arShield {

    using SafeMath for uint;

    // Buffer amount for division.
    uint256 constant private BUFFER = 1e18;
    // Whether or not the contract is locked.
    bool public locked;
    // Beneficiary may withdraw any extra Ether after a claims period.
    address payable public beneficiary;
    // Block at which users must be holding tokens to receive a payout.
    uint256 public payoutBlock;
    // User who deposited to notify of a hack.
    address public depositor;
    // 0.25% paid for minting in order to pay for the first week of coverage--can be immediately liquidated.
    uint256[] public feesToLiq;
    // Different amounts to charge as a fee for each protocol.
    uint256[] public feePerBase;
    // User => timestamp of when minting was requested.
    mapping (address => MintRequest) public mintRequests;
    // Whether user has been paid for a specific payout block.
    mapping (address => mapping (address => bool)) public paid;

    // The armorToken that this shield issues.
    IERC20 public arToken;
    // Protocol token that we're providing protection for.
    IERC20 public pToken;
    // Underlying token of the pToken.
    IERC20 public uToken;
    // Oracle to find uToken price.
    Oracle public oracle;
    // Controller of the arShields.
    ShieldController public controller;
    // Coverage bases that we need to be paying.
    address[] public covBases;

    // Time and amount a user would like to mint.
    struct MintRequest {
        uint32 requestTime;
        uint112 arAmount;
        uint112 pAmount;
    }

    event MintRequest(address indexed user, uint256 amount, uint256 timestamp);
    event MintFinalized(address indexed user, uint256 amount, uint256 timestamp);
    event MintCancelled(address indexed user, uint256 amount, uint256 timestamp);
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
        address _arToken,
        address _pToken, 
        address _uToken, 
        address _oracle,
        address[] _covBases
    )
      external
    {
        pToken = IERC20(_pToken);
        uToken = IERC20(_uToken);
        oracle = Oracle(_oracle);
        controller = Controller(msg.sender);
    }

    /**
     * @dev User deposits pToken, is returned arToken. Amount returned is judged based off amount in contract.
     *      Amount returned will likely be more than deposited because pTokens will be removed to pay for cover.
     * @param _pAmount Amount of pTokens to deposit to the contract.
     * @param _beneficiary User who a finalized mint may be sent to
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
            
            uint256 fee = findFee(_pAmount);
            uint256 arAmount = arValue( _pAmount.sub(fee) );

            pToken.transferFrom(msg.sender, address(this), _pAmount);
            mintRequests[msg.sender] = MintRequest(block.timestamp, arAmount);
            emit MintRequest(msg.sender, arAmount, block.timestamp);
            
        } else if (block.timestamp.sub(controller.mintDelay) > mintRequest.requestTime) {
            
            delete mintRequests[_beneficiary];
            arToken.mint(_beneficiary, mintRequest.requestAmount);
            emit MintFinalized(_beneficiary, mintRequest.requestAmount, block.timestamp);
        
        }
    }

    /**
     * @dev Cancel a mint call in case the user does not want to finalize. Also used if lock occurs before finalize.
    **/
    function cancelMint()
      external
    {
        MintRequest memory request = mintRequests[msg.sender];
        delete mintRequests[_beneficiary];
        pToken.transfer(msg.sender, request.pAmount);
        emit MintCancelled(msg.sender, request.pAmount, block.timestamp);
    }

    function redeem(
        uint256 _arAmount
    )
      external
    {
        uint256 pAmount = pValue(_arAmount);
        arToken.transferFrom(msg.sender, address(this), _arAmount);
        arToken.burn(_arAmount);
        uint256 fee = findFee(pAmount);
        arToken.transfer( msg.sender, pAmount.sub(fee) );
        emit Redemption(msg.sender, _arAmount, block.timestamp);
    }

    /**
     * @dev Find the fee for deposit and withdrawal.
    **/
    function findFee(
        uint256 _pAmount
    )
      public
      view
    returns(
        uint256 totalFee
    )
    {
        for (uint256 i = 0; i < feesToLiq.length; i++) {
            uint256 fee = _pAmount.mul(feePerBase[i]).div(DENOMINATOR);
            feesToLiq[i] = feesToLiq[i].add(fee);
            totalFee += fee;
        }
    }

    /**
     * @dev Liquidate for payment for coverage by selling to people at oracle price.
    **/
    function liquidate(
        uint256 covId
    )
      external
      override
      payable
      nonReentrant
    {
        // Get full amounts for liquidation here.
        (
         uint256 ethOwed, 
         uint256 tokenValue, 
         uint256 tokensOwed,
         uint256 tokenFees
        ) = liqAmts(covId);

        // determine eth value and amount of tokens to pay?
        (
         uint256 tokensOut,
         uint256 feesPaid,
         uint256 ethValue
        ) = payAmts(msg.value);

        CovBase(covBases[covId]).updateShield({value: ethIn})(ethValue);
        feesToLiq[covId] -= feesPaid;
        pToken.safeTransfer(msg.sender, tokensOut);
    }

    /**
     * @dev Amounts owed to be liquidated.
     * @return ethOwed Amount of Ether owed to coverage base.
     * @return tokensOwed Amount of tokens owed to liquidator for that Ether.
    **/
    function liqAmts(uint256 covId)
      public
      view
    returns(
        uint256 ethOwed,
        uint256 tokenValue,
        uint256 tokensOwed,
        uint256 tokenFees
    )
    {
        // Find amount owed in Ether, find amount owed in protocol tokens.
        ethOwed = CovBase(covBases[covId]).getOwed( address(this) );
        tokenValue = oracle.getTokensOwed(ethOwed, pToken, uTokenLink);

        tokenFees = feesToLiq[covId];
        // Find the Ether value of the mint fees we have.
        uint256 ethFees = ethOwed * tokenFees / tokenValue;

        tokensOwed = tokenValue.add(tokenFees);
        // Add a bonus of 0.5%.
        uint256 liqBonus = (tokensOwed * controller.bonus / DENOMINATOR);

        tokensOwed = tokensOwed.add(liqBonus);
        ethOwed = ethOwed.add(ethFees);
    }

    function payAmts(
        uint256 _ethIn
    )
      public
      view
    returns(
        uint256 tokensOut,
        uint256 feesPaid,
        uint256 ethValue
    )
    {
        tokensOut = ethIn
                    .mul(tokensOwed)
                    .div(ethOwed);
        feesPaid = ethIn
                    .mul(tokenFees)
                    .div(ethOwed);
        ethValue = pToken.balanceOf( address(this) )
                    .mul(ethOwed)
                    .div(tokenValue);
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
     * @dev Claim funds if you were holding tokens on the payout block.
    **/
    function claim()
      external
      locked
    {
        uint256 balance = arToken.balanceOf(msg.sender, payoutBlock);
        require(balance > 0 && !paid[payoutBlock][msg.sender], "Sender did not have funds on payout block.");
        paid[payoutBlock][msg.sender] = true;
        msg.sender.transfer(payoutAmt * balance / 1 ether);
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
     * @dev Used by controller to confirm that a hack happened, which then locks the contract in anticipation of claims.
    **/
    function confirmHack(
        uint256 _payoutBlock,
        uint256 _payoutAmt
    )
      external
      onlyGov
    {
        // TODO: change to safe transfer
        depositor.transfer(depositReward);
        delete depositor;
        payoutBlock = _payoutBlock;
        payoutAmt = _payoutAmt;
        emit HackConfirmed(_payoutBlock, block.timestamp);
    }
    
    /**
     * @dev Used by controller to confirm that a hack happened, which then locks the contract in anticipation of claims.
    **/
    function unlock()
      external
      locked
      onlyGov
    {
        locked = false;
        lockTime = 0;
        delete payoutBlock;
        delete payoutAmt;
        emit Unlocked(block.timestamp);
    }

    /**
     * @dev Change the fees taken for minting and redeeming.
     * @param _newFees Array for each of the 
    **/
    function changeFees(
        uint256[] calldata _newFees
    )
      external
      onlyGov
    {
        require(_newFees.length == feePerBase.length, "Improper fees length.");
        for (uint256 i = 0; i < _newFees.length; i++) feePerBase[i] = _newFees[i];
    }

}