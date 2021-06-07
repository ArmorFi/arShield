// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import '../interfaces/IOracle.sol';
import '../interfaces/ICovBase.sol';
import '../interfaces/IController.sol';
import '../interfaces/IArmorToken.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @title Armor Shield
 * @dev arShield base provides the base functionality of arShield contracts.
 * @author Armor.Fi -- Robert M.C. Forster
**/
contract arShield {

    // Denominator for % fractions.
    uint256 constant DENOMINATOR = 1000;
    // Whether or not the contract is locked.
    bool public locked;
    // Beneficiary may withdraw any extra Ether after a claims period.
    address payable public beneficiary;
    // Block at which users must be holding tokens to receive a payout.
    uint256 public payoutBlock;
    // Amount to payout in Ether per token for the most recent hack.
    uint256 public payoutAmt;
    // User who deposited to notify of a hack.
    address public depositor;
    // 0.25% paid for minting in order to pay for the first week of coverage--can be immediately liquidated.
    uint256[] public feesToLiq;
    // Different amounts to charge as a fee for each protocol.
    uint256[] public feePerBase;
    // Whether user has been paid for a specific payout block.
    mapping (uint256 => mapping (address => uint256)) public paid;

    address public uTokenLink;
    // The armorToken that this shield issues.
    IArmorToken public arToken;
    // Protocol token that we're providing protection for.
    IERC20 public pToken;
    // Oracle to find uToken price.
    IOracle public oracle;
    // Used for universal variables (all shields) such as bonus for liquidation.
    IController public controller;
    // Coverage bases that we need to be paying.
    ICovBase[] public covBases;

    event Mint(address indexed user, uint256 amount, uint256 timestamp);
    event Redemption(address indexed user, uint256 amount, uint256 timestamp);
    event Locked(address reporter, uint256 timestamp);
    event Unlocked(uint256 timestamp);
    event HackConfirmed(uint256 payoutBlock, uint256 timestamp);

    modifier onlyGov 
    {
        require(msg.sender == controller.governor(), "Only governance may call this function.");
        _;
    }

    modifier isLocked 
    {
        require(locked, "You may not do this while the contract is unlocked.");
        _;
    }

    // Only allow minting when there are no claims processing (people withdrawing to receive Ether).
    modifier notLocked 
    {
        require(!locked, "You may not do this while the contract is locked.");
        _;
    }
    
    receive() external payable {}
    
    /**
     * @dev Initialize the contract
     * @param _pToken The protocol token we're protecting.
    **/
    function initialize(
        address _arToken,
        address _pToken, 
        address _uTokenLink, 
        address _oracle,
        address[] calldata _covBases,
        uint256[] calldata _fees
    )
      external
    {
        require(address(arToken) == address(0), "Contract already initialized.");
        arToken = IArmorToken(_arToken);
        pToken = IERC20(_pToken);
        uTokenLink = _uTokenLink;
        oracle = IOracle(_oracle);
        controller = IController(msg.sender);

        // CovBases and fees must always be the same length.
        require(_covBases.length == _fees.length, "Improper length array.");
        for(uint256 i = 0; i < _covBases.length; i++) {
            covBases.push( ICovBase(_covBases[i]) );
            feePerBase.push( _fees[i] );
            feesToLiq.push(0);
        }
    }

    /**
     * @dev User deposits pToken, is returned arToken. Amount returned is judged based off amount in contract.
     *      Amount returned will likely be more than deposited because pTokens will be removed to pay for cover.
     * @param _pAmount Amount of pTokens to deposit to the contract.
    **/
    function mint(
        uint256 _pAmount
    )
      external
      notLocked
    {    
        uint256 fee = findFee(_pAmount);
        uint256 arAmount = arValue(_pAmount - fee);
        pToken.transferFrom(msg.sender, address(this), _pAmount);
        arToken.mint(msg.sender, arAmount);
        emit Mint(msg.sender, arAmount, block.timestamp);
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
        pToken.transfer(msg.sender, pAmount - fee);
        
        emit Redemption(msg.sender, _arAmount, block.timestamp);
    }

    /**
     * @dev Find the fee for deposit and withdrawal.
    **/
    function findFee(
        uint256 _pAmount
    )
      internal
    returns(
        uint256 totalFee
    )
    {
        for (uint256 i = 0; i < feesToLiq.length; i++) {
            uint256 fee = _pAmount
                          * feePerBase[i]
                          / DENOMINATOR;
            feesToLiq[i] += fee;
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
      payable
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
        ) = payAmts(
            msg.value,
            ethOwed,
            tokenValue,
            tokensOwed,
            tokenFees
        );

        covBases[covId].updateShield{value: msg.value}(ethValue);
        feesToLiq[covId] -= feesPaid;
        pToken.transfer(msg.sender, tokensOut);
    }

    /**
     * @dev Amounts owed to be liquidated.
     * @return ethOwed Amount of Ether owed to coverage base.
     * @return tokenValue Amount of tokens owed to liquidator for that Ether.
     * @return tokensOwed Amount of tokens owed to liquidator for that Ether.
     * @return tokenFees Amount of tokens owed to liquidator for that Ether.
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
        ethOwed = covBases[covId].getOwed( address(this) );
        tokenValue = oracle.getTokensOwed(ethOwed, address(pToken), uTokenLink);

        tokenFees = feesToLiq[covId];
        // Find the Ether value of the mint fees we have.
        uint256 ethFees = ethOwed 
                          * tokenFees 
                          / tokenValue;

        tokensOwed = tokenValue + tokenFees;
        // Add a bonus of 0.5%.
        uint256 liqBonus = tokensOwed 
                           * controller.bonus()
                           / DENOMINATOR;

        tokensOwed += liqBonus;
        ethOwed += ethFees;
    }

    function payAmts(
        uint256 _ethIn,
        uint256 _ethOwed,
        uint256 _tokenValue,
        uint256 _tokensOwed,
        uint256 _tokenFees
    )
      public
      view
    returns(
        uint256 tokensOut,
        uint256 feesPaid,
        uint256 ethValue
    )
    {
        tokensOut = _ethIn
                    * _tokensOwed
                    / _ethOwed;
        feesPaid = _ethIn
                   * _tokenFees
                   / _ethOwed;
        ethValue = pToken.balanceOf( address(this) )
                   * _ethOwed
                   / _tokenValue;
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
        uint256 totalSupply = arToken.totalSupply();
        if (totalSupply == 0) return _arAmount;

        // TODO: Must subtract fees to liquidate here.
        pAmount = pToken.balanceOf( address(this) ) 
                  * _arAmount 
                  / arToken.totalSupply();
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
        uint256 balance = pToken.balanceOf( address(this) );
        if (balance == 0) return _pAmount;

        // TODO: Must subtract fees to liquidate here.
        arAmount = arToken.totalSupply() 
                   * _pAmount 
                   / pToken.balanceOf( address(this) );
    }

    /**
     * @dev Claim funds if you were holding tokens on the payout block.
    **/
    function claim()
      external
      isLocked
    {
        uint256 balance = arToken.balanceOfAt(msg.sender, payoutBlock);
        uint256 amount = (payoutAmt 
                         * balance 
                         / 1 ether) 
                         - paid[payoutBlock][msg.sender];
        require(balance > 0 && amount > 0, "Sender did not have funds on payout block.");
        paid[payoutBlock][msg.sender] += amount;
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev Funds may be withdrawn to beneficiary if any are leftover after a hack.
     * @param _token Address of the token to withdraw excess for. Cannot be protocol token.
    **/
    function withdrawExcess(address _token)
      external
      notLocked
    {
        if ( _token == address(0) ) beneficiary.transfer( address(this).balance );
        else if ( _token != address(pToken) ) IERC20(_token).transfer( beneficiary, IERC20(_token).balanceOf( address(this) ) );
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
        require(msg.value == controller.depositAmt(), "You must pay the deposit amount to notify a hack.");
        depositor = msg.sender;
        locked = true;
        emit Locked(msg.sender, block.timestamp);
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
        payable(depositor).transfer( controller.depositAmt() );
        delete depositor;
        payoutBlock = _payoutBlock;
        payoutAmt = _payoutAmt;
        emit HackConfirmed(_payoutBlock, block.timestamp);
    }
    
    /**
     * @dev Block a payout if an address minted tokens after a hack occurred.
     *      There are ways people can mess with this to make it annoying to ban people,
     *      but ideally the presence of this function alone will stop malicious minting.
     * 
     *      Although it's not a likely scenario, the reason we put amounts in here
     *      is to avoid a bad actor sending a bit to a legitimate holder and having their
     *      full balance banned from receiving a payout.
     * @param _users List of users to ban from receiving payout.
     * @param _amounts Bad amounts (in Ether) that the user should not be paid.
     * @param _payoutBlock The block at which the hack occurred.
    **/
    function banPayout(
        address[] calldata _users,
        uint256[] calldata _amounts,
        uint256 _payoutBlock
    )
      external
      onlyGov
    {
        for(uint256 i = 0; i < _users.length; i++) paid[_payoutBlock][_users[i]] += _amounts[i];
    }
    
    /**
     * @dev Used by controller to confirm that a hack happened, which then locks the contract in anticipation of claims.
    **/
    function unlock()
      external
      isLocked
      onlyGov
    {
        locked = false;
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