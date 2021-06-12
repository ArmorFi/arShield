// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import './ArmorToken2.sol';
import '../general/Governable.sol';
import '../interfaces/IarShield.sol';
import '../interfaces/ICovBase.sol';
import '../proxies/OwnedUpgradeabilityProxy.sol';


contract ShieldController is Governable {

    // Liquidation bonus for users who are liquidating funds.
    uint256 public bonus;
    // Fee % for referrals. 10000 == 100% of the rest of the fees.
    uint256 public refFee;
    // Amount that needs to be deposited to lock the contract.
    uint256 public depositAmt;
    // List of all arShields
    address[] private arShields;

    constructor(
        uint256 _bonus,
        uint256 _refFee,
        uint256 _depositAmt
    )
    {
        initializeOwnable();
        bonus = _bonus;
        refFee = _refFee;
        depositAmt = _depositAmt;
    }

    /**
     * @dev Create a new arShield from an already-created family.
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
            token,
            _pToken,
            _uTokenLink,
            _oracle,
            payable(msg.sender),
            _covBases,
            _fees
        );
        
        for(uint256 i = 0; i < _covBases.length; i++) ICovBase(_covBases[i]).editShield(proxy, true);

        arShields.push(proxy);
        OwnedUpgradeabilityProxy( payable(proxy) ).transferProxyOwnership(msg.sender);
    }

    /**
     * @dev Delete a shield. We use both shield address and index for safety.
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
     * @dev Edit the discount on Chainlink price that liquidators receive.
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
     * @dev Change amount required to deposit to lock a shield.
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
     * @dev Change amount required to deposit to lock a shield.
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
     * @dev Get all arShields.
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
