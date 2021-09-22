// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@umb-network/toolbox/dist/contracts/IChain.sol";
import "@umb-network/toolbox/dist/contracts/IRegistry.sol";
import "@umb-network/toolbox/dist/contracts/lib/ValueDecoder.sol";

/**
 * @title Umbrella Oracle
 * @notice Umbrella Oracle uses umb.network to find the price of underlying Yearn assets,
 *         then determines amount of yTokens to pay for Ether needed by shield.
 * @author Armor.fi -- Ryuhei Matsuda
 **/
contract UmbrellaOracle is Ownable {
    IRegistry public immutable umbrellaRegistry;
    mapping(address => bytes32) public umbrellaKeys;
    bytes32 public ethUmbrellaKey;

    constructor(address _umbrellaRegistry, bytes32 _ethUmbrellaKey) {
        require(_umbrellaRegistry != address(0), "zero address");
        umbrellaRegistry = IRegistry(_umbrellaRegistry);
        ethUmbrellaKey = _ethUmbrellaKey;
    }

    function setUmbrellaKey(address _token, bytes32 _key) external onlyOwner {
        umbrellaKeys[_token] = _key;
    }

    function _verifyUmbrellaProof(
        address _token,
        bytes32[] calldata _proof,
        bytes memory _value
    ) private view {
        IChain chain = _chain();
        uint256 lastBlockId = uint256(chain.getLatestBlockId());

        bool success = chain.verifyProofForBlock(
            lastBlockId,
            _proof,
            abi.encodePacked(umbrellaKeys[_token]),
            _value
        );
        require(success, "token value is invalid");
    }

    /**
     * @notice Get the amount of tokens owed for the input amount of Ether.
     * @param _ethOwed Amount of Ether that the shield owes to coverage base.
     * @param _yToken Address of the Yearn token to find value of.
     * @param _tokenProof Umbrella proof for yToken.
     * @param _tokenPrice Umbrella price of yToken.
     * @return yOwed Amount of Yearn token owed for this amount of Ether.
     **/
    function getTokensOwed(
        uint256 _ethOwed,
        address _yToken,
        bytes32[] calldata _tokenProof,
        uint256 _tokenPrice
    ) external view returns (uint256 yOwed) {
        _verifyUmbrellaProof(
            _yToken,
            _tokenProof,
            abi.encodePacked(_tokenPrice)
        );
        uint256 uOwed = _ethOwed * getEthPrice();
        yOwed = uOwed / _tokenPrice;
    }

    /**
     * @notice Get the Ether owed for an amount of tokens that must be paid for.
     * @param _tokensOwed Amounts of tokens to find value of.
     * @param _yToken Address of the Yearn token that value is being found for.
     * @param _tokenProof Umbrella proof for yToken.
     * @param _tokenPrice Umbrella price of yToken.
     * @return ethOwed Amount of Ether owed for this amount of tokens.
     **/
    function getEthOwed(
        uint256 _tokensOwed,
        address _yToken,
        bytes32[] calldata _tokenProof,
        uint256 _tokenPrice
    ) external view returns (uint256 ethOwed) {
        _verifyUmbrellaProof(
            _yToken,
            _tokenProof,
            abi.encodePacked(_tokenPrice)
        );

        uint256 ethOwed = (_tokensOwed * _tokenPrice) / getEthPrice();
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

    function toBytes32(bytes memory data)
        internal
        pure
        returns (bytes32 parsedData)
    {
        assembly {
            parsedData := mload(add(data, 32))
        }
    }
}
