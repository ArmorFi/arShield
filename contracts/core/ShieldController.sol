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

    // Token to oracle for different types of contracts.
    mapping(address => address) public oracles;
    // Which shield corresponds to a given protocol token.
    mapping
    // One token may have multiple shields because of stacked risk differences.
    mapping(address => address[]) public pTokenToShield;
    // Which protocol token corresponds to a given Armor token.
    mapping (address => address) arTokenToPToken;
    // Which Armor token(s) corresponds to a given protocol token.
    mapping (address => address[]) pTokenToArToken;

    /**
     * @dev Create a new arShield from an already-created family.
    **/
    function createShield(address _uToken, address _pool, bytes8 _family)
      external
      onlyGov
    {

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
