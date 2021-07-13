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
    // List of all arShields
    address[] private arShields;

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
     * @notice Create a new arShield from an already-created family.
     * @param _name Name of the armorToken to be created.
     * @param _symbol Symbol of the armorToken to be created.
     * @param _oracle Address of the family's oracle contract to find token value.
     * @param _pToken Protocol token that the shield will use.
     * @param _uTokenLink Address of the ChainLink contract for the underlying token.
     * @param _masterCopy Mastercopy for the arShield proxy.
     * @param _fees Mint/redeem fee for each coverage base.
     * @param _covBases Coverage bases that the shield will subscribe to.
    **/
    function createShield(
        string calldata _name,
        string calldata _symbol,
        address _oracle,
        address _pToken,
        address _uTokenLink,
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
            _uTokenLink,
            _fees,
            _covBases
        );
        
        for(uint256 i = 0; i < _covBases.length; i++) ICovBase(_covBases[i]).editShield(proxy, true);

        arShields.push(proxy);
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
        if (arShields[_idx] == _shield) delete arShields[_idx];
        arShields[_idx] = arShields[arShields.length - 1];
        arShields.pop();
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

}
