// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import '../client/ArmorClient.sol';
import '../interfaces/IarShield.sol';
import '../interfaces/IController.sol';

/**
 * @title Coverage Base
 * @notice Coverage base takes care of all Armor Core interactions for arShields.
 * @author Armor.fi -- Robert M.C. Forster
**/
contract CoverageBase is ArmorClient {
    
    // Denominator for coverage percent.
    uint256 public constant DENOMINATOR = 10000;

    // The protocol that this contract purchases coverage for.
    address public protocol;
    // Percent of funds from shields to cover.
    uint256 public coverPct;
    // Current cost per second for all Ether on contract.
    uint256 public totalCostPerSec;
    // Current cost per second per Ether.
    uint256 public costPerEth;
    // sum of cost per Ether for every second -- cumulative lol.
    uint256 public cumCost;
    // Last update of cumCost.
    uint256 public lastUpdate;
    // Total Ether value to be protecting in the contract.
    uint256 public totalEthValue;
    // Separate variable from above because there may be less than coverPct coverage available.
    uint256 public totalEthCoverage;
  
    // Value in Ether and last updates of each shield vault.
    mapping (address => ShieldStats) public shieldStats;

    // Controller holds governance contract.
    IController public controller;
    
    // Every time a shield updates it saves the full contracts cumulative cost, its Ether value, and 
    struct ShieldStats {
        uint128 lastCumCost;
        uint128 ethValue;
        uint128 lastUpdate;
        uint128 unpaid;
    }
    
    // Only let the governance address or the ShieldController edit these functions.
    modifier onlyGov 
    {
        require(msg.sender == controller.governor() || msg.sender == address(controller), "Sender is not governor.");
        _;
    }

    /**
     * @notice Just used to set the controller for the coverage base.
     * @param _controller ShieldController proxy address.
     * @param _protocol Address of the protocol to cover (from Nexus Mutual).
     * @param _coverPct Percent of the cover to purchase -- 10000 == 100%.
    **/
    function initialize(
        address _controller,
        address _protocol,
        uint256 _coverPct
    )
      external
    {
        require(protocol == address(0), "Contract already initialized.");
        controller = IController(_controller);
        protocol = _protocol;
        coverPct = _coverPct;
    }
    
    // Needed to receive a claim payout.
    receive() external payable {}

    /**
     * @notice Called by a keeper to update the amount covered by this contract on arCore.
    **/
    function updateCoverage()
      external
    {
        ArmorCore.deposit( address(this).balance );
        uint256 available = getAvailableCover();
        ArmorCore.subscribe( protocol, available );
        totalCostPerSec = getCoverageCost(available);
        totalEthCoverage = available;
        checkpoint();
    }
    
    /**
     * @notice arShield uses this to update the value of funds on their contract and deposit payments to here.
     *      We're okay with being loose-y goose-y here in terms of making sure shields pay (no cut-offs, timeframes, etc.).
     * @param _newEthValue The new Ether value of funds in the shield contract.
    **/
    function updateShield(
        uint256 _newEthValue
    )
      external
      payable
    {
        ShieldStats memory stats = shieldStats[msg.sender];
        require(stats.lastUpdate > 0, "Only arShields may access this function.");
        
        // Determine how much the shield owes for the last period.
        uint256 owed = getShieldOwed(msg.sender);
        uint256 unpaid = owed <= msg.value ? 
                         0 
                         : owed - msg.value;

        totalEthValue = totalEthValue 
                        - uint256(stats.ethValue)
                        + _newEthValue;

        checkpoint();

        shieldStats[msg.sender] = ShieldStats( 
                                    uint128(cumCost), 
                                    uint128(_newEthValue), 
                                    uint128(block.timestamp), 
                                    uint128(unpaid) 
                                  );
    }
    
    /**
     * @notice CoverageBase tells shield what % of current coverage it must pay.
     * @param _shield Address of the shield to get owed amount for.
     * @return owed Amount of Ether that the shield owes for past coverage.
    **/
    function getShieldOwed(
        address _shield
    )
      public
      view
    returns(
        uint256 owed
    )
    {
        ShieldStats memory stats = shieldStats[_shield];
        
        // difference between current cumulative and cumulative at last shield update
        uint256 pastDiff = cumCost - uint256(stats.lastCumCost);
        uint256 currentDiff = costPerEth * ( block.timestamp - uint256(lastUpdate) );
        
        owed = (uint256(stats.ethValue) 
                  * pastDiff
                  / 1 ether)
                + (uint256(stats.ethValue)
                  * currentDiff
                  / 1 ether)
                + uint256(stats.unpaid);
    }
    
    /**
     * @notice Record total values from last period and set new ones.
    **/
    function checkpoint()
      internal
    {
        cumCost += costPerEth * (block.timestamp - lastUpdate);
        costPerEth = totalCostPerSec
                     * 1 ether 
                     / totalEthValue;
        lastUpdate = block.timestamp;
    }
    
    /**
     * @notice Get the available amount of coverage for all shields' current values.
    **/
    function getAvailableCover()
      public
      view
    returns(
        uint256
    )
    {
        uint256 ideal = totalEthValue 
                        * coverPct 
                        / DENOMINATOR;
        return ArmorCore.availableCover(protocol, ideal);

    }
    
    /**
     * @notice Get the cost of coverage for all shields' current values.
     * @param _amount The amount of coverage to get the cost of.
    **/
    function getCoverageCost(uint256 _amount)
      public
      view
    returns(
        uint256
    )
    {
        return ArmorCore.calculatePricePerSec(protocol, _amount);
    }
    
    /**
     * @notice Check whether a new Ether value is available for purchase.
     * @param _newEthValue The new Ether value of the shield.
     * @return allowed True if we may purchase this much more coverage.
    **/
    function checkCoverage(
      uint256 _newEthValue
    )
      public
      view
    returns(
      bool allowed
    )
    {
      uint256 desired = (totalEthValue 
                         + _newEthValue
                         - uint256(shieldStats[msg.sender].ethValue) )
                        * coverPct
                        / DENOMINATOR;
      allowed = ArmorCore.availableCover( protocol, desired ) == desired;
    }

    /**
     * @notice Either add or delete a shield.
     * @param _shield Address of the shield to edit.
     * @param _active Whether we want it to be added or deleted.
    **/
    function editShield(
        address _shield,
        bool _active
    )
      external
      onlyGov
    {
        // If active, set timestamp of last update to now, else delete.
        if (_active) shieldStats[_shield] = ShieldStats( 
                                              uint128(cumCost), 
                                              0, 
                                              uint128(block.timestamp), 
                                              0 );
        else delete shieldStats[_shield]; 
    }
    
    /**
     * @notice Withdraw an amount of funds from arCore.
    **/
    function withdraw(address payable _beneficiary, uint256 _amount)
      external
      onlyGov
    {
        ArmorCore.withdraw(_amount);
        _beneficiary.transfer(_amount);
    }
    
    /**
     * @notice Cancel entire arCore plan.
    **/
    function cancelCoverage()
      external
      onlyGov
    {
        ArmorCore.cancelPlan();
    }
    
    /**
     * @notice Governance may call to a redeem a claim for Ether that this contract held.
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
        ArmorCore.claim(protocol, _hackTime, _amount);
    }
    
    /**
     * @notice Governance may disburse funds from a claim to the chosen shields.
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
        require(shieldStats[_shield].lastUpdate > 0 && IarShield(_shield).locked(), "Shield is not authorized to use this contract or shield is not locked.");
        _shield.transfer(_amount);
    }
    
    /**
     * @notice Change the percent of coverage that should be bought. For example, 500 means that 50% of Ether value will be covered.
     * @param _newPct New percent of coverage to be bought--1000 == 100%.
    **/
    function changeCoverPct(
        uint256 _newPct
    )
      external
      onlyGov
    {
        require(_newPct <= 10000, "Coverage percent may not be greater than 100%.");
        coverPct = _newPct;    
    }
    
}