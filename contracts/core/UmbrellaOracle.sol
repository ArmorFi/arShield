// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@umb-network/toolbox/dist/contracts/IChain.sol";
import "@umb-network/toolbox/dist/contracts/IRegistry.sol";
import "@umb-network/toolbox/dist/contracts/lib/ValueDecoder.sol";
import "../interfaces/IOracle.sol";

/**
 * @title Umbrella Oracle
 * @notice Umbrella Oracle uses umb.network to find the price of underlying Yearn assets,
 *         then determines amount of yTokens to pay for Ether needed by shield.
 * @author Armor.fi -- Ryuhei Matsuda
 **/
contract UmbrellaOracle is Ownable, IOracle {
    using ValueDecoder for bytes;

    IRegistry public immutable umbrellaRegistry;
    bytes32 public ethUmbrellaKey;

    constructor(address _umbrellaRegistry, bytes32 _ethUmbrellaKey) {
        require(_umbrellaRegistry != address(0), "zero address");
        umbrellaRegistry = IRegistry(_umbrellaRegistry);
        ethUmbrellaKey = _ethUmbrellaKey;
    }

    function _verifyUmbrellaProof(
        bytes32 tokenKey,
        bytes32[] calldata _proof,
        bytes memory _value
    ) private view {
        IChain chain = _chain();
        uint32 lastBlockId = chain.getLatestBlockId();

        bool success = chain.verifyProofForBlock(
            uint256(lastBlockId),
            _proof,
            abi.encodePacked(tokenKey),
            _value
        );
        require(success, "token value is invalid");
    }

    /**
     * @notice Get the amount of tokens owed for the input amount of Ether.
     * @param _ethOwed Amount of Ether that the shield owes to coverage base.
     * @param _yKey Umbrella key for yToken-USD
     * @param _tokenProof Umbrella proof for yToken.
     * @param _tokenValue Umbrella price value of yToken.
     * @return yOwed Amount of Yearn token owed for this amount of Ether.
     **/
    function getTokensOwed(
        uint256 _ethOwed,
        bytes32 _yKey,
        bytes32[] calldata _tokenProof,
        bytes calldata _tokenValue
    ) external view override returns (uint256 yOwed) {
        _verifyUmbrellaProof(_yKey, _tokenProof, _tokenValue);
        uint256 uOwed = _ethOwed * getEthPrice();
        yOwed = uOwed / _tokenValue.toUint();
    }

    /**
     * @notice Get the Ether owed for an amount of tokens that must be paid for.
     * @param _tokensOwed Amounts of tokens to find value of.
     * @param _yKey Umbrella key for yToken-USD
     * @param _tokenProof Umbrella proof for yToken.
     * @param _tokenValue Umbrella price value of yToken.
     * @return ethOwed Amount of Ether owed for this amount of tokens.
     **/
    function getEthOwed(
        uint256 _tokensOwed,
        bytes32 _yKey,
        bytes32[] calldata _tokenProof,
        bytes calldata _tokenValue
    ) external view override returns (uint256 ethOwed) {
        _verifyUmbrellaProof(_yKey, _tokenProof, _tokenValue);

        uint256 ethOwed = (_tokensOwed * _tokenValue.toUint()) / getEthPrice();
    }

    /**
     * @notice get ETH/USD price.
     * @return ETH price in USD.
     **/
    function getEthPrice() public view returns (uint256) {
        (uint256 value, uint256 timestamp) = _chain().getCurrentValue(
            ethUmbrellaKey
        );

        require(timestamp > 0, "value does not exists");

        return value;
    }

    function _chain() internal view returns (IChain umbChain) {
        umbChain = IChain(umbrellaRegistry.getAddress("Chain"));
    }
}
