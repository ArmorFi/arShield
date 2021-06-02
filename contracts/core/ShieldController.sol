pragma solidity ^0.8.0;
import './IarShield.sol';
import './OwnedUpgradeabilityProxy.sol';

contract ShieldController {

    // Amount of time between when a mint request is made and finalized.
    uint256 public mintDelay;
    // Liquidation bonus for users who are liquidating funds.
    uint256 public liqBonus;
    // Lock bonus for depositors who correctly lock a contract.
    uint256 public depositReward;
    // Amount that needs to be deposited to lock the contract.
    uint256 public depositAmount;

    address[] public arShields;

    /**
     * @dev Create a new arShield from an already-created family.
    **/
    function createShield(
        address _masterCopy,
        address _pToken,
        address _uTokenLink,
        address[] _covBases,
        address _oracle,
        uint256[] calldata _fees
    )
      external
      onlyGov
    {
        address token = new ArmorToken(_name, _symbol);
        address proxy = new Proxy(_masterCopy);
        
        IarShield(proxy).initialize(
            _pToken,
            _uTokenLink,
            _covBases,
            _oracle,
            _fees
        );
        
        for(uint256 i = 0; i < covBases.length; i++) {
            _covBases[i].addShield(proxy);
        }

        arShields.push(proxy);
    }

    /**
     * @dev Controller can change different delay periods on the contract.
    **/
    function changeDelay(
        uint256 _mintDelay
    )
      external
      onlyGov
    {
        mintDelay = _mintDelay;
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

}
