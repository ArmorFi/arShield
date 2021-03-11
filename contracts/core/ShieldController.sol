pragma solidity ^0.8.0;

contract ShieldController {

    // Master contract for each family of arShields (Yearn, Uniswap, Balancer, etc.)
    mapping(bytes8 => address) public matriarchs;

    // Individual arShields grouped by family.
    mapping(bytes8 => address[]) public shields;

    /**
     * @dev Create a new arShield from an already-created family.
    **/
    function createShield(address _uToken, address _pool, bytes8 _family)
      external
      onlyOwner
    {

    }

    /**
     * @dev Trigger a refill of arCore balance either by particular family, particular shield, or all.
    **/
    function triggerRefills(address[] calldata _shield)
      external
    {

    }
    
    /**
     * @dev Add a master for a family of arShields. Can also be used to change an existing.
    **/
    function addFamily(bytes8 _family, address _matriarch)
      external
      onlyOwner
    {

    }

    /**
     * @dev Lock either a specific shield or a family of shields.
    **/
    function lockShields(address[] calldata _shield)
      external
      onlyOwner
    {

    }

    /**
     * @dev Change some variables on a list of shields. It would be nice to be able to have these on master, but we don't want too many calls between contracts.
    **/
    function changeDelay(address[] calldata _shields, uint256 _mintDelay, uint256 _lockTime)
      external
      onlyOwner
    {

    }

}
