// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import './ArmorToken.sol';
import '../general/Governable.sol';
import '../interfaces/IarShield.sol';
import '../interfaces/ICovBase.sol';
import '../proxies/OwnedUpgradeabilityProxy.sol';

/** 
 * @title Shield Controller
 * @notice Shield Controller is in charge of creating new shields and storing universal variables.
 * @author Armor.fi -- Robert M.C. Forster
**/
contract ShieldController is Governable {

    // Liquidation bonus for users who are liquidating funds.
    uint256 public bonus;
    // Fee % for referrals. 10000 == 100% of the rest of the fees.
    uint256 public refFee;
    // Amount that needs to be deposited to lock the contract.
    uint256 public depositAmt;
    // Default beneficiary of all shields.
    address payable public beneficiary;
    // Mapping of arShields to determine if call is allowed.
    mapping (address => bool) public shieldMapping;
    // List of all arShields.
    address[] private arShields;
    // List of all arTokens.
    address[] private arTokens;

    // Event sent from arShield for frontend to get all referrals from one source.
    event ShieldAction(
        address user, 
        address indexed referral,
        address indexed shield,
        address indexed token,
        uint256 amount,
        uint256 refFee,
        bool mint,
        uint256 timestamp
    ); 

    function initialize(
        uint256 _bonus,
        uint256 _refFee,
        uint256 _depositAmt
    )
      external
    {
        require(arShields.length == 0, "Contract already initialized.");
        initializeOwnable();
        bonus = _bonus;
        refFee = _refFee;
        depositAmt = _depositAmt;
        beneficiary = payable(msg.sender);
    }

    // In case a token has Ether lost in it we need to be able to receive.
    receive() external payable {}

    /**
     * @notice Greatly helps frontend to have all shield referral events in one spot.
     * @param _user The user making the contract interaction.
     * @param _referral The referral of the contract interaction.
     * @param _shield The address of the shield calling.
     * @param _pToken The address of the token for the shield.
    **/
    function emitAction(
        address _user,
        address _referral,
        address _shield,
        address _pToken,
        uint256 _amount,
        uint256 _refFee,
        bool _mint
    )
      external
    {
        require(shieldMapping[msg.sender] == true, "Only arShields may call emitEvents.");
        emit ShieldAction(_user, _referral, _shield, _pToken, _amount, _refFee, _mint, block.timestamp);
    }

    /**
     * @notice Create a new arShield from an already-created family.
     * @param _name Name of the armorToken to be created.
     * @param _symbol Symbol of the armorToken to be created.
     * @param _oracle Address of the family's oracle contract to find token value.
     * @param _pToken Protocol token that the shield will use.
     * @param _umbrellaKey Umbrella key for pToken-USD
     * @param _masterCopy Mastercopy for the arShield proxy.
     * @param _fees Mint/redeem fee for each coverage base.
     * @param _covBases Coverage bases that the shield will subscribe to.
    **/
    function createShield(
        string calldata _name,
        string calldata _symbol,
        address _oracle,
        address _pToken,
        bytes32 _umbrellaKey,
        address _masterCopy,
        uint256[] calldata _fees,
        address[] calldata _covBases
    )
      external
      onlyGov
    {
        address proxy = address( new OwnedUpgradeabilityProxy(_masterCopy) );
        address token = address( new ArmorToken(proxy, _name, _symbol) );
        
        IarShield(proxy).initialize(
            _oracle,
            _pToken,
            token,
            _umbrellaKey,
            _fees,
            _covBases
        );
        
        for(uint256 i = 0; i < _covBases.length; i++) ICovBase(_covBases[i]).editShield(proxy, true);

        arTokens.push(token);
        arShields.push(proxy);
        shieldMapping[proxy] = true;

        OwnedUpgradeabilityProxy( payable(proxy) ).transferProxyOwnership(msg.sender);
    }

    /**
     * @notice Delete a shield. We use both shield address and index for safety.
     * @param _shield Address of the shield to delete from array.
     * @param _idx Index of the shield in the arShields array.
    **/
    function deleteShield(
        address _shield,
        uint256 _idx
    )
      external
      onlyGov
    {
        if (arShields[_idx] == _shield) {
            arShields[_idx] = arShields[arShields.length - 1];
            arTokens[_idx] = arTokens[arTokens.length - 1];
            arShields.pop();
            arTokens.pop();
            delete shieldMapping[_shield];
        }
    }

    /**
     * @notice Claim any lost tokens on an arShield contract.
     * @param _armorToken Address of the Armor token that has tokens or ether lost in it.
     * @param _token The address of the lost token.
     * @param _beneficiary Address to send the tokens to.
    **/
    function claimTokens(
        address _armorToken,
        address _token,
        address payable _beneficiary
    )
      external
      onlyGov
    {
        ArmorToken(_armorToken).claimTokens(_token);
        if (_token == address(0)) _beneficiary.transfer(address(this).balance);
        else ArmorToken(_token).transfer( _beneficiary, ArmorToken(_token).balanceOf( address(this) ) );
    }

    /**
     * @notice Edit the discount on Chainlink price that liquidators receive.
     * @param _newBonus The new bonus amount that will be given to liquidators.
    **/
    function changeBonus(
        uint256 _newBonus
    )
      external
      onlyGov
    {
        bonus = _newBonus;
    }

    /**
     * @notice Change amount required to deposit to lock a shield.
     * @param _depositAmt New required deposit amount in Ether to lock a contract.
    **/
    function changeDepositAmt(
        uint256 _depositAmt
    )
      external
      onlyGov
    {
        depositAmt = _depositAmt;
    }

    /**
     * @notice Change amount required to deposit to lock a shield.
     * @param _refFee New fee to be paid to referrers. 10000 == 100%
     *                of the protocol fees that will be charged.
    **/
    function changeRefFee(
        uint256 _refFee
    )
      external
      onlyGov
    {
        refFee = _refFee;
    }

    /**
     * @notice Change the main beneficiary of all shields.
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
     * @notice Get all arShields.
    **/
    function getShields()
      external
      view
    returns(
        address[] memory shields
    )
    {
        shields = arShields;
    }

    /**
     * @notice Get all arTokens.
    **/
    function getTokens()
      external
      view
    returns(
        address[] memory tokens
    )
    {
        tokens = arTokens;
    }

    /**
     * @notice Used by frontend to get a list of balances for the user in one call.
     *         Start and end are included in case the list gets too long for the gas of one call.
     * @param _user Address to get balances for.
     * @param _start Start index of the arTokens list. Inclusive.
     * @param _end End index of the arTokens list (if too high, defaults to length). Exclusive.
    **/
    function getBalances(
        address _user, 
        uint256 _start, 
        uint256 _end
    )
      public
      view
    returns(
        address[] memory tokens,
        uint256[] memory balances
    )
    {
        if (_end > arTokens.length || _end == 0) _end = arTokens.length;
        tokens = new address[](_end - _start);
        balances = new uint[](_end - _start);

        for (uint256 i = _start; i < _end; i++) {
            tokens[i] = arTokens[i];
            balances[i] = ArmorToken(arTokens[i]).balanceOf(_user);
        }
    }

}
