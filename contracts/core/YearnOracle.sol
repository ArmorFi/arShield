// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import '../interfaces/IYearn.sol';
import '../interfaces/AggregatorV3Interface.sol';


/**
 * @title Yearn Oracle
 * @dev Yearn Oracle uses Chainlink to find the price of underlying Yearn assets,
 *      then determines amount of yTokens to pay for Ether needed by shield.
 * @author Armor.fi -- Robert M.C. Forster, Taek Lee
**/
contract YearnOracle {

    /**
     * @dev Get the amount of tokens owed for the input amount of Ether.
     * @param _ethOwed Amount of Ether that the shield owes to coverage base.
     * @param _yToken Address of the Yearn token to find value of.
     * @param _uTokenLink Chainlink address to get price of the underlying token.
     * @return yOwed Amount of Yearn token owed for this amount of Ether.
    **/
    function getTokensOwed(
        uint256 _ethOwed,
        address _yToken,
        address _uTokenLink
    )
      external
      view
    returns(
        uint256 yOwed
    )
    {   
        uint256 uOwed = ethToU(_ethOwed, _uTokenLink);
        yOwed = uToY(_yToken, uOwed);
    }
    
    /**
     * @dev Get the Ether owed for an amount of tokens that must be paid for.
     * @param _tokensOwed Amounts of tokens to find value of.
     * @param _yToken Address of the Yearn token that value is being found for.
     * @param _uTokenLink ChainLink address for the underlying token.
     * @return ethOwed Amount of Ether owed for this amount of tokens.
    **/
    function getEthOwed(
        uint256 _tokensOwed,
        address _yToken,
        address _uTokenLink
    )
      external
      view
    returns(
        uint256 ethOwed
    )
    {
        uint256 yPerU = uToY(_yToken, 1 ether);
        uint256 ethPerU = _findEthPerToken(_uTokenLink);
        uint256 ethPerY = yPerU
                          * ethPerU
                          / 1 ether;

        ethOwed = _tokensOwed
                  * ethPerY
                  / 1 ether;
    }

    /**
     * @dev Ether amount to underlying token owed.
     * @param _ethOwed Amount of Ether owed to the coverage base.
     * @param _uTokenLink Chainlink oracle address for the underlying token.
     * @return uOwed Amount of underlying tokens owed.
    **/
    function ethToU(
        uint256 _ethOwed,
        address _uTokenLink
    )
      public
      view
    returns(
        uint256 uOwed
    )
    {
        uint256 ethPerToken = _findEthPerToken(_uTokenLink);
        uOwed = _ethOwed 
                * 1 ether 
                / ethPerToken;
    }

    /**
     * @dev Underlying tokens to Yearn tokens conversion.
     * @param _yToken Address of the Yearn token.
     * @param _uOwed Amount of underlying tokens owed.
     * @return yOwed Amount of Yearn tokens owed.
    **/
    function uToY(
        address _yToken,
        uint256 _uOwed
    )
      public
      view
    returns(
        uint256 yOwed
    )
    {
        uint256 oneYToken = IYearn(_yToken).pricePerShare();
        yOwed = _uOwed 
                * (10 ** IYearn(_yToken).decimals())
                / oneYToken;
    }
    
    /**
     * @dev Finds the amount of cover required to protect all holdings and returns Ether value of 1 token.
     * @param _uTokenLink Chainlink oracle address for the underlying token.
     * @return ethPerToken Ether value of each pToken.
    **/
    function _findEthPerToken(
        address _uTokenLink
    )
      internal
      view
    returns (
        uint256 ethPerToken
    )
    {
        (/*roundIf*/, int tokenPrice, /*startedAt*/, /*timestamp*/, /*answeredInRound*/) = AggregatorV3Interface(_uTokenLink).latestRoundData();
        ethPerToken = uint256(tokenPrice);
    }
    
}
