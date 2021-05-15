pragma solidity 0.6.6;
import '../client/ArmorClient.sol';

contract CoverageBase is ArmorClient, Ownable {
    
    // The protocol that this contract purchases coverage for.
    address public protocol;
    
    // Percent of funds from shields to cover.
    uint256 public coverPct;
    
    // Total Ether value to be protecting in the contract.
    uint256 public totalEthValue;
    
    // sum of cost per token for every second -- cumulative lol
    uint256 public cumCost;
    
    // Last update of cumCost and cumValue.
    uint256 public lastUpdate;
    
    // Denominator for coverage percent.
    uint256 public constant DENOMINATOR = 1000;
    
    // Shields that are authorized to use this contract.
    mapping (address => bool) public shields;
    
    // The last amount that a shield paid for coverage at.
    mapping (address => uint256) public lastCumCost;
    
    // lmao having too much fun.
    mapping (address => uint256) public lastCumValue;
    
    // Value in Ether of each shield vault.
    mapping (address => ShieldStats) public shieldStats;
    
    // TODO: can be packed tighter
    struct ShieldStats {
        uint256 ethValue;
        uint256 lastCumCost;
        uint256 lastUpdate;
    }
    
    receive() external payable {}
    
    function updateCoverage()
      external
    {
        uint256 coverage = totalEthValue * coverPct / DENOMINATOR;
        // get coverage cost
        ArmorClient.subscribe(protocol, coverage);
        checkpoint();
        currentCost = coverageCost;
    }
    
    /**
     * @dev Record total values from last period.
    **/
    function checkpoint()
      internal
    {
        cumCost += currentCost * (block.timestamp - lastUpdate) * 1 ether / totalEthValue;
        lastUpdate = block.timestamp;
    }
    
    /**
     * @dev arShield uses this to update the value of funds on their contract and deposit payments to here.
    **/
    function deposit(
        uint256 _newEthValue
    )
      external
      payable
    {
        // do we also do the last payment here?
        require(shields[msg.sender], "Only arShields may access this function.");

        
        // need a variable to do cost per token every time a deposit is made
        
        // do we want to fail the transfer if not enough is given?
        // shield owes: 
        ShieldStats memory stats = shieldStats[msg.sender];
        uint256 costDiff = cumCost - stats.lastCumCost;
        uint256 currentDiff = currentCost * (block.timestamp - lastUpdate);
        uint256 owed = ethValues[msg.sender] * costDiff + ethValues[msg.sender] * currentDiff;
        
        totalEthValue = totalEthValue - ethValues[msg.sender] + _newEthValue;
        ethValues[msg.sender] = _newEthValue;
        
        // update cumCost and lastUpdate here as well
        
        shieldStats[msg.sender] = ShieldStates(_newEthValue, cumCost, block.timestamp);
        checkpoint()
    }
    
    /**
     * @dev CoverageBase tells shield what % of current coverage it must pay.
    **/
    function getShieldCost(
        address _shield
    )
      public
      view
    {
        uint256 shieldValue = ethValues[_shield];
        // WON'T WORK
        return getCoverageCost() * shieldValue / totalEthValue;
    }
    
    /**
     * @dev Cancel entire arCore plan.
    **/
    function cancelCoverage()
      external
      onlyGov
    {
        ArmorClient.cancelPlan();
    }
    
    /**
     * @dev Governance may call to a redeem a claim for Ether that this contract held.
     * @param _hackTime Time that the hack occurred.
     * @param _amount Amount of funds to be redeemed.
    **/
    function redeemClaim(
        uint256 _hackTime,
        uint256 _amount
    )
      external
      onlyGov
    {
        ArmorClient.claim(protocol, _hackTime, _amount);
    }
    
    /**
     * @dev Governance may disburse funds from a claim to the chosen shields.
     * @param _shield Address of the shield to disburse funds to.
     * @param _amount Amount of funds to disburse to the shield.
    **/
    function disburseClaim(
        address payable _shield,
        uint256 _amount
    )
      external
      onlyGov
    {
        require(shields[_shield], "Shield is not authorized to use this contract.");
        _shield.transfer(_amount);
    }
    
    function getCoverage()
      public
      view
    returns (uint256)
    {
        return totalEthValue * coverPct / DENOMINATOR;
    }
    
    function getCoverageCost()
      public
      view
    returns (uint256)
    {
        return ArmorClient.cost( getCoverage() );
    }
    
    function getShieldCost(address _shield)
      public
      view
    returns (uint256)
    {
        
    }
    
    /**
     * @dev Change the percent of coverage that should be bought. For example, 500 means that 50% of Ether value will be covered.
     * @param _newPct New percent of coverage to be bought--1000 == 100%.
    **/
    function changeCoverPct(
        uint256 _newPct
    )
      external
      onlyGov
    {
        require(_newPct <= 1000, "Coverage percent may not be greater than 100%.");
        coverPct = _newPct;    
    }
    
}
