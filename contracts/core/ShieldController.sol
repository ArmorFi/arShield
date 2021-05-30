pragma solidity ^0.8.0;
import './OwnedUpgradeabilityProxy.sol';

contract ShieldController {

    // Amount of time between when a mint request is made and finalized.
    uint256 public mintDelay;
    // Fee charged when minting and withdrawing.
    uint256 public mintFee;
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
        address _master,
        address _arToken,
        address _pToken,
        address _uTokenLink,
        address[] _covBases,
        address _oracle
    )
      external
      onlyGov
    {
        // create Armor token
        // create owned upgradeability proxy using master address
        // initialize proxy with data above
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
     * @dev Controller can change different delay periods on the contract.
    **/
    function changeFee(
        uint256 _mintfee
    )
      external
      onlyGov
    {
        mintFee = _mintFee;
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
