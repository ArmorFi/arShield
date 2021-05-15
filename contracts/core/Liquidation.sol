pragma solidity 0.6.12;


contract YearnLiquidation is Liquidation {
    
    function liquidate()
      external
      override
    {
        // this will get the amount owed in Ether
        uint256 owed = super.getOwed();
        uint256 toRedeem = ethToUnderlying(owed);
        uint256 underlyingOwed = redeemYearn(owed);
        liquidate(owed);
    }
    
    function redeemYearn()
      external
      override
    {
        // call Yearn to liquidate token into underlying
    }
    
    function ethToUnderlying(
        uint256 _ethAmount
    )
      public
      view
    {
        // find eth value of the underlying tokens
    }
    
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
