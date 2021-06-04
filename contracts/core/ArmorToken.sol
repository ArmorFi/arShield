// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @dev Example of ArmorToken using yDai
**/
contract ArmorToken is ERC20 {

    address public arShield;

    constructor(address _arShield, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        arShield = _arShield;
    }
    
    /**
     * @dev Only arShield is allowed to mint and burn tokens.
    **/
    modifier onlyArShield {
        require(msg.sender == arShield, "Sender is not arNXM Vault.");
        _;
    }
    
    function mint(address _to, uint256 _amount)
      external
      onlyArShield
    returns (bool)
    {
        _mint(_to, _amount);
        return true;
    }
    
    function burn(uint256 _amount)
      external
      onlyArShield
    returns (bool)
    {
        _burn(msg.sender, _amount);
        return true;
    }

}