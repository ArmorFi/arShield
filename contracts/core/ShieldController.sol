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
    // Amount that needs to be deposited to lock the contract.
    uint256 public depositAmt;
    // List of all arShields
    address[] public arShields;

    constructor()
    {
        initializeOwnable();
    }

    /**
     * @dev Create a new arShield from an already-created family.
    **/
    function createShield(
        string calldata _name,
        string calldata _symbol,
        address _masterCopy,
        address _pToken,
        address _uTokenLink,
        address _oracle,
        address[] calldata _covBases,
        uint256[] calldata _fees
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
