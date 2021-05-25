pragma solidity 0.6.12;

import './IYearn.sol';


contract YearnLiquidation is Liquidation {

    uint256 constant DENOMINATOR = 1000;
    // Bonus received by liquidators. 5 == 0.5% off Chainlink price.
    uint256 public bonus;
    uint256 public lock;
    
    modifier nonReentrant {
        uint256 start = lock;
        lock++;
        _;
        require(lock == start + 1, "Re-entrancy protection.");
    }
    
    function liquidate()
      external
      override
      nonReentrant
    {
        // Find amount owed in Ether, find amount owed in underlying ('u'), redeem Yearn for that amount, send to liquidator, get Ether back.
        uint256 ethOwed = getOwed();
        require(msg.value >= ethOwed, "Must send correct Ether amount.");
        
        uint256 baseRedeem = ethToU(ethOwed);
        // Add a bonus of 0.5%.
        uint256 bonusRedeem = baseRedeem * bonus / DENOMINATOR;
        uint256 yToRedeem = uToY(bonusRedeem);
        redeemYearn(yToRedeem);
        uToken.safeTransfer(msg.sender, bonusRedeem);
        
        uint256 ethValue = yToken.balanceOf( address(this) ) * ethOwed / yToRedeem; 
        covBase.updateShield(ethValue);
    }
    
    function uToY(
        uint256 _uShares
    )
      public
      view
    returns(
        uint256 yShares
    )
    {
        uint256 oneYToken = yVault.calc(1 ether);
        yShares = _uShares * 1 ether / oneYToken;
    }
    
    function redeemYearn(uint256 _shares)
      internal
    {
        yVault.withdraw(_shares, address(this), 1);
    }
    
    function ethToUnderlying(
        uint256 _ethAmount
    )
      public
      view
    returns(
        uint256 uOwed
    )
    {
        uint256 ethPrice = chainlink.ethPrice;
        uint256 uPrice = chainlink.uPrice;
        
    }
    
    /**
     * @dev Finds the amount of cover required to protect all holdings and returns Ether value of 1 token.
     * @return ethPerToken Ether value of each pToken.
    **/
    function _findEthPerToken()
      internal
    returns (
        uint256 ethPerToken
    )
    {
        // change to chainlink
    }
    
    /**
     * @dev Edit the discount on Chainlink price that liquidators receive.
    **/
    function editBonus(
        uint256 _newBonus
    )
      external
      onlyOwner
    {
        bonus = _newBonus;
    }
    
}

contract YearnCRVLiquidation is arShield {
    
    function liquidate()
    
    // liquidate:
        // ask coverageBase how much we need to pay 
        // get price with super.chainlink
        // sell on super.uniswap
        // coverageBase.deposit()
        
    // purchase
        // ask coverageBase how much we need to pay
        // get price with super.chainlink
        // msg.value to return correct tokens
        // coverageBase.deposit()
        
    // redeem
        // if super.
    
}

contract UniLiquidation is arShield {
    
    function liquidate()
    
    // liquidate:
        // ask coverageBase how much we need to pay 
        // get price with super.chainlink
        // sell on super.uniswap
        // coverageBase.deposit()
        
    // purchase
        // ask coverageBase how much we need to pay
        // get price with super.chainlink
        // msg.value to return correct tokens
        // coverageBase.deposit()
        
    // redeem
        // if super.
    
}
