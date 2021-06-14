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
 * @author Armor.fi -- Robert M.C. Forster
**/
contract arShield {

    // Denominator for % fractions.
    uint256 constant DENOMINATOR = 10000;
    
    // Whether or not the pool has capped coverage.
    bool public capped;
    // Whether or not the contract is locked.
    bool public locked;
    // Address that will receive default referral fees and excess eth/tokens.
    address payable public beneficiary;
    // User who deposited to notify of a hack.
    address public depositor;
    // Amount to payout in Ether per token for the most recent hack.
    uint256 public payoutAmt;
    // Block at which users must be holding tokens to receive a payout.
    uint256 public payoutBlock;
    // Total amount to be paid to referrers.
    uint256 public refTotal;
    // 0.25% paid for minting in order to pay for the first week of coverage--can be immediately liquidated.
    uint256[] public feesToLiq;
    // Different amounts to charge as a fee for each protocol.
    uint256[] public feePerBase;
    // Total tokens to protect in the vault (tokens - fees).
    uint256 public totalTokens;

    // Balance of referrers.
    mapping (address => uint256) public refBals;
   // Whether user has been paid for a specific payout block.
    mapping (uint256 => mapping (address => uint256)) public paid;

    // Chainlink address for the underlying token.
    address public uTokenLink;
    // Protocol token that we're providing protection for.
    IERC20 public pToken;
    // Oracle to find uToken price.
    IOracle public oracle;
    // The armorToken that this shield issues.
    IArmorToken public arToken;
    // Coverage bases that we need to be paying.
    ICovBase[] public covBases;
    // Used for universal variables (all shields) such as bonus for liquidation.
    IController public controller;

    event Unlocked(uint256 timestamp);
    event Locked(address reporter, uint256 timestamp);
    event HackConfirmed(uint256 payoutBlock, uint256 timestamp);
    event Mint(address indexed user, uint256 amount, uint256 timestamp);
    event Redemption(address indexed user, uint256 amount, uint256 timestamp);

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
     * @dev Controller immediately initializes contract with this.
     * @param _oracle Address of our oracle for this family of tokens.
     * @param _pToken The protocol token we're protecting.
     * @param _arToken The Armor token that the vault controls.
     * @param _uTokenLink ChainLink contract for the underlying token.
     * @param _beneficiary Address that will receive excess tokens and automatic referral.
     * @param _fees Mint/redeem fees for each coverage base.
     * @param _covBases Addresses of the coverage bases to pay for coverage.
    **/
    function initialize(
        address _oracle,
        address _pToken,
        address _arToken,
        address _uTokenLink, 
        address payable _beneficiary,
        uint256[] calldata _fees,
        address[] calldata _covBases
    )
      external
    {
        require(address(arToken) == address(0), "Contract already initialized.");
        uTokenLink = _uTokenLink;
        beneficiary = _beneficiary;

        pToken = IERC20(_pToken);
        oracle = IOracle(_oracle);
        arToken = IArmorToken(_arToken);
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
     * @param _referrer The address that referred the user to arShield.
    **/
    function mint(
        uint256 _pAmount,
        address _referrer
    )
      external
      notLocked
    {
        address user = msg.sender;

        // fee is total including refFee
        (
         uint256 fee, 
         uint256 refFee, 
         uint256 totalFees,
         uint256[] memory newFees
        ) = _findFees(_pAmount);

        uint256 arAmount = arValue(_pAmount - fee);
        pToken.transferFrom(user, address(this), _pAmount);
        _saveFees(newFees, _referrer, refFee);

        // If this vault is capped in its coverage, we check whether the mint should be allowed.
        if (capped) {
            uint256 ethValue = getEthValue(pToken.balanceOf( address(this) ) - totalFees);
            require(checkCapped(ethValue), "Not enough coverage available.");
        }

        arToken.mint(user, arAmount);
        emit Mint(user, arAmount, block.timestamp);
    }

    /**
     * @dev Redeem arTokens for underlying pTokens.
     * @param _arAmount Amount of arTokens to redeem.
     * @param _referrer The address that referred the user to arShield.
    **/
    function redeem(
        uint256 _arAmount,
        address _referrer
    )
      external
    {
        address user = msg.sender;
        uint256 pAmount = pValue(_arAmount);
        arToken.transferFrom(user, address(this), _arAmount);
        arToken.burn(_arAmount);
        
        (
         uint256 fee, 
         uint256 refFee,
         uint256 totalFees,
         uint256[] memory newFees
        ) = _findFees(pAmount);

        pToken.transfer(user, pAmount - fee);
        _saveFees(newFees, _referrer, refFee);

        // If we update this above, the coverage base may try to buy more coverage than it has funds for.
        // If we don't update this here, users will get stuck paying for coverage that they are not using.
        uint256 ethValue = getEthValue(pToken.balanceOf( address(this) ) - totalFees);
        for (uint256 i = 0; i < covBases.length; i++) covBases[i].updateShield(ethValue);

        emit Redemption(user, _arAmount, block.timestamp);
    }

    /**
     * @dev Liquidate for payment for coverage by selling to people at oracle price.
    **/
    function liquidate(
        uint256 _covId
    )
      external
      payable
    {
        // Get full amounts for liquidation here.
        (
         uint256 ethOwed, 
         uint256 tokensOwed,
         uint256 tokenFees
        ) = liqAmts(_covId);
        require(msg.value <= ethOwed, "Too much Ether paid.");

        // Determine eth value and amount of tokens to pay?
        (
         uint256 tokensOut,
         uint256 feesPaid,
         uint256 ethValue
        ) = payAmts(
            msg.value,
            ethOwed,
            tokensOwed,
            tokenFees
        );

        covBases[_covId].updateShield{value:msg.value}(ethValue);
        feesToLiq[_covId] -= feesPaid;
        pToken.transfer(msg.sender, tokensOut);
    }

    /**
     * @dev Claim funds if you were holding tokens on the payout block.
    **/
    function claim()
      external
      isLocked
    {
        // Find balance at the payout block, multiply by the amount per token to pay, subtract anything paid.
        uint256 balance = arToken.balanceOfAt(msg.sender, payoutBlock);
        uint256 amount = payoutAmt
                         * (balance - paid[payoutBlock][msg.sender])
                         / 1 ether;

        require(balance > 0 && amount > 0, "Sender did not have funds on payout block.");
        paid[payoutBlock][msg.sender] += amount;
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev Used by referrers to withdraw their owed balance.
    **/
    function withdraw(
        address _user
    )
      external
    {
        uint256 balance = refBals[_user];
        refBals[_user] = 0;
        pToken.transfer(_user, balance);
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

        pAmount = ( pToken.balanceOf( address(this) ) - totalFeeAmts() )
                  * _arAmount 
                  / totalSupply;
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

        arAmount = arToken.totalSupply()
                   * _pAmount 
                   / ( balance - totalFeeAmts() );
    }

    /**
     * @dev Amounts owed to be liquidated.
     * @param _covId Coverage Base ID lol
     * @return ethOwed Amount of Ether owed to coverage base.
     * @return tokensOwed Amount of tokens owed to liquidator for that Ether.
     * @return tokenFees Amount of tokens owed to liquidator for that Ether.
    **/
    function liqAmts(
        uint256 _covId
    )
      public
      view
    returns(
        uint256 ethOwed,
        uint256 tokensOwed,
        uint256 tokenFees
    )
    {
        // Find amount owed in Ether, find amount owed in protocol tokens.
        // If nothing is owed to coverage base, don't use getTokensOwed.
        ethOwed = covBases[_covId].getShieldOwed( address(this) );
        if (ethOwed > 0) tokensOwed = oracle.getTokensOwed(ethOwed, address(pToken), uTokenLink);

        tokenFees = feesToLiq[_covId];
        tokensOwed += tokenFees;
        require(tokensOwed > 0, "No fees are owed.");

        // Find the Ether value of the mint fees we have.
        uint256 ethFees = ethOwed > 0 ?
                            ethOwed
                            * tokenFees
                            / tokensOwed
                          : getEthValue(tokenFees);
        ethOwed += ethFees;

        // Add a bonus for liquidators (0.5% to start).
        uint256 liqBonus = tokensOwed 
                           * controller.bonus()
                           / DENOMINATOR;
        tokensOwed += liqBonus;
    }

    /**
     * @dev Find amount to pay a liquidator--needed because a liquidator may not pay all Ether. 
    **/
    function payAmts(
        uint256 _ethIn,
        uint256 _ethOwed,
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
        // Actual amount we're liquidating (liquidator may not pay full Ether owed).
        tokensOut = _ethIn
                    * _tokensOwed
                    / _ethOwed;

        // Amount of fees for this protocol being paid.
        feesPaid = _ethIn
                   * _tokenFees
                   / _ethOwed;

        // Ether value of all of the contract minus what we're liquidating.
        ethValue = (pToken.balanceOf( address(this) ) 
                    - _tokenFees
                    - totalFeeAmts())
                   * _ethOwed
                   / _tokensOwed;
    }

    /**
     * @dev Find total amount of tokens that are not to be covered (ref fees, tokens to liq, liquidator bonus).
     * @return totalOwed Total amount of tokens owed in fees.
    **/
    function totalFeeAmts()
      public
      view
    returns(
        uint256 totalOwed
    )
    {
        for (uint256 i = 0; i < covBases.length; i++) {
            uint256 ethOwed = covBases[i].getShieldOwed( address(this) );
            if (ethOwed > 0) totalOwed += oracle.getTokensOwed(ethOwed, address(pToken), uTokenLink);
            totalOwed += feesToLiq[i];
        }

        // Add a bonus for liquidators (0.5% to start).
        uint256 liqBonus = totalOwed 
                            * controller.bonus()
                            / DENOMINATOR;
        totalOwed += liqBonus;
        totalOwed += refTotal;
    }

    /**
     * @dev If the shield requires full coverage, check coverage base to see if it is available.
     * @param _ethValue Ether value of the new tokens.
     * @return allowed True if the deposit is allowed.
    **/
    function checkCapped(
        uint256 _ethValue
    )
      public
      view
    returns(
        bool allowed
    )
    {
        if (capped) {
            for(uint256 i = 0; i < covBases.length; i++) {
                if( !covBases[i].checkCoverage(_ethValue) ) return false;
            }
        }
        allowed = true;
    }

    /**
     * Find the Ether value of a certain amount of pTokens.
     * @param _pAmount The amount of pTokens to find Ether value for.
     * @return ethValue Ether value of the pTokens (in Wei).
    **/
    function getEthValue(
        uint256 _pAmount
    )
      public
      view
    returns(
        uint256 ethValue
    )
    {
        ethValue = oracle.getEthOwed(_pAmount, address(pToken), uTokenLink);
    }

    /**
     * @dev Find the fee for deposit and withdrawal.
     * @param _pAmount The amount of pTokens to find the fee of.
     * @return userFee coverage + mint fees + liquidator bonus + referral fee.
     * @return refFee Referral fee.
     * @return totalFees Total fees owed from the contract including referrals (used to calculate amount to cover).
     * @return newFees New fees to save in feesToLiq.
    **/
    function _findFees(
        uint256 _pAmount
    )
      internal
      view
    returns(
        uint256 userFee,
        uint256 refFee,
        uint256 totalFees,
        uint256[] memory newFees
    )
    {
        // Find protocol fees for each coverage base.
        newFees = feesToLiq;
        for (uint256 i = 0; i < newFees.length; i++) {
            totalFees += newFees[i];
            uint256 fee = _pAmount
                          * feePerBase[i]
                          / DENOMINATOR;
            newFees[i] += fee;
            userFee += fee;
        }

        // Add referral fee.
        refFee = userFee 
                 * controller.refFee() 
                 / DENOMINATOR;
        userFee += refFee;

        // Add liquidator bonus.
        uint256 liqBonus = (userFee - refFee) 
                           * controller.bonus()
                           / DENOMINATOR;
        userFee += liqBonus;
        totalFees += userFee + refTotal;
    }

    /**
     * @dev Save new coverage fees and referral fees.
     * @param liqFees Fees associated with depositing to a coverage base.
     * @param _refFee Fee given to the address that referred this user.
    **/
    function _saveFees(
        uint256[] memory liqFees,
        address _referrer,
        uint256 _refFee
    )
      internal
    {
        refTotal += _refFee;
        if ( _referrer != address(0) ) refBals[_referrer] += _refFee;
        else refBals[beneficiary] += _refFee;
        for (uint256 i = 0; i < liqFees.length; i++) feesToLiq[i] = liqFees[i];
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
     * @param _payoutBlock Block that user must have had tokens at. Will not be the same as when the hack occurred
     *                     because we will need to give time for users to withdraw from dexes and such if needed.
     * @param _payoutAmt The amount of Ether PER TOKEN that users will be given for this claim.
    **/
    function confirmHack(
        uint256 _payoutBlock,
        uint256 _payoutAmt
    )
      external
      isLocked
      onlyGov
    {
        // low-level call to avoid push problems
        payable(depositor).call{value: controller.depositAmt()}("");
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
      isLocked
      onlyGov
    {
        locked = false;
        delete payoutBlock;
        delete payoutAmt;
        emit Unlocked(block.timestamp);
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
        else if ( _token != address(pToken) ) {
            IERC20(_token).transfer( beneficiary, IERC20(_token).balanceOf( address(this) ) );
        }
    }

    /**
     * @dev Block a payout if an address minted tokens after a hack occurred.
     *      There are ways people can mess with this to make it annoying to ban people,
     *      but ideally the presence of this function alone will stop malicious minting.
     * 
     *      Although it's not a likely scenario, the reason we put amounts in here
     *      is to avoid a bad actor sending a bit to a legitimate holder and having their
     *      full balance banned from receiving a payout.
     * @param _payoutBlock The block at which the hack occurred.
     * @param _users List of users to ban from receiving payout.
     * @param _amounts Bad amounts (in arToken wei) that the user should not be paid.
    **/
    function banPayouts(
        uint256 _payoutBlock,
        address[] calldata _users,
        uint256[] calldata _amounts
    )
      external
      onlyGov
    {
        for (uint256 i = 0; i < _users.length; i++) paid[_payoutBlock][_users[i]] += _amounts[i];
    }

    /**
     * @dev Change the fees taken for minting and redeeming.
     * @param _newFees Array for each of the new fees. 10 == 0.1% fee.
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

    /**
     * @dev Change the main beneficiary of the shield.
     * @param _beneficiary New address to withdraw excess funds and get default referral fees.
    **/
    function changeBeneficiary(
        address payable _beneficiary
    )
      external
      onlyGov
    {
        beneficiary = _beneficiary;
    }

    /**
     * @dev Change whether this arShield has a cap on tokens submitted or not.
     * @param _capped True if there should now be a cap on the vault.
    **/
    function changeCapped(
        bool _capped
    )
      external
      onlyGov
    {
        capped = _capped;
    }

}