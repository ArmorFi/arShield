pragma solidity 0.6.12;
import './IYearn.sol';
import './AggregatorV3Interface';

contract YearnLiquidation is Liquidation {

    uint256 constant DENOMINATOR = 1000;
    // Bonus received by liquidators. 5 == 0.5% off Chainlink price.
    uint256 public bonus;
    uint256 public lock;
    AggregatorV3Interface public chainlink;

    // TODO: This doesn't work
    modifier nonReentrant {
        uint256 start = lock;
        lock++;
        _;
        require(lock == start + 1, "Re-entrancy protection.");
    }
    
    function liquidate()
      external
      override
      payable
      nonReentrant
    {
        // Find amount owed in Ether, find amount owed in underlying ('u'), redeem Yearn for that amount, send to liquidator, get Ether back.
        uint256 ethOwed = getOwed();
        require(msg.value >= ethOwed, "Must send correct Ether amount.");
        
        uint256 baseRedeem = ethToU(ethOwed);
        // Add a bonus of 0.5%.
        uint256 bonusRedeem = baseRedeem + (baseRedeem * bonus / DENOMINATOR);
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
        uint256 oneYToken = yVault.getPricePerFullShare();
        yShares = _uShares * 1 ether / oneYToken;
    }
    
    function ethToU(
        uint256 _ethAmount
    )
      public
      view
    returns(
        uint256 uOwed
    )
    {
        uint256 tokenPerEth = _findTokenPerEth();
        uOwed = _ethAmount * tokenPerEth;
    }
    
    /**
     * @dev Finds the amount of cover required to protect all holdings and returns Ether value of 1 token.
     * @return tokenPerEth Ether value of each pToken.
    **/
    function _findTokenPerEth()
      internal
    returns (
        uint256 tokenPerEth
    )
    {
        (/*roundIf*/, int ethPrice, /*startedAt*/, /*timestamp*/, /*answeredInRound*/) = ethChainlink.getThePrice();
        (/*roundIf*/, int tokenPrice, /*startedAt*/, /*timestamp*/, /*answeredInRound*/) = tokenChainlink.getThePrice();
        return ethPrice *  1 ether / tokenPrice;
    }

    /**
     * @dev Redeem yTokens for their underlying values.
     * @param _shares The amount of shares of the yToken to redeem.
    **/
    function redeemYearn(
        uint256 _shares
    )
      internal
    {
        yVault.redeem(_shares, address(this), 1);
    }

    /**
     * @dev Edit the discount on Chainlink price that liquidators receive.
     * @param _newBonus The new bonus amount that will be given to liquidators.
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
    
    uint256 constant DENOMINATOR = 1000;
    // Bonus received by liquidators. 5 == 0.5% off Chainlink price.
    uint256 public bonus;
    uint256 public lock;
    AggregatorV3Interface public chainlink;

    modifier nonReentrant {
        uint256 start = lock;
        lock++;
        _;
        require(lock == start + 1, "Re-entrancy protection.");
    }
    
    function liquidate()
      external
      override
      payable
      nonReentrant
    {
        // Find amount owed in Ether, find amount owed in underlying ('u'), redeem Yearn for that amount, send to liquidator, get Ether back.
        uint256 ethOwed = getOwed();
        require(msg.value >= ethOwed, "Must send correct Ether amount.");
        
        uint256 baseRedeem = ethToU(ethOwed);
        // Add a bonus of 0.5%.
        uint256 bonusRedeem = baseRedeem + (baseRedeem * bonus / DENOMINATOR);
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
        uint256 oneYToken = yVault.getPricePerFullShare();
        yShares = _uShares * 1 ether / oneYToken;
    }
    
    function ethToU(
        uint256 _ethAmount
    )
      public
      view
    returns(
        uint256 uOwed
    )
    {
        uint256 tokenPerEth = _findTokenPerEth();
        uOwed = _ethAmount * tokenPerEth;
    }
    
    /**
     * @dev Finds the amount of cover required to protect all holdings and returns Ether value of 1 token.
     * @return tokenPerEth Ether value of each pToken.
    **/
    function _findTokenPerEth()
      internal
    returns (
        uint256 tokenPerEth
    )
    {
        (/*roundIf*/, int ethPrice, /*startedAt*/, /*timestamp*/, /*answeredInRound*/) = ethChainlink.getThePrice();
        (/*roundIf*/, int tokenPrice, /*startedAt*/, /*timestamp*/, /*answeredInRound*/) = tokenChainlink.getThePrice();
        return ethPrice *  1 ether / tokenPrice;
    }

    /**
     * @dev Redeem yTokens for their underlying values.
     * @param _shares The amount of shares of the yToken to redeem.
    **/
    function redeemYearn(
        uint256 _shares
    )
      internal
    {
        yVault.redeem(_shares, address(this), 1);
    }

    /**
     * @dev Edit the discount on Chainlink price that liquidators receive.
     * @param _newBonus The new bonus amount that will be given to liquidators.
    **/
    function editBonus(
        uint256 _newBonus
    )
      external
      onlyOwner
    {
        bonus = _newBonus;
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
