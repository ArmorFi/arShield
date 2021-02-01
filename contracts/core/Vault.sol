// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental SMTChecker;

import "../interfaces/IArmorMaster.sol";
import "../interfaces/IBalanceManager.sol";
import "../interfaces/IClaimManager.sol";
import "../interfaces/IPlanManager.sol";
import "../interfaces/IERC20.sol";
import "../general/SafeERC20.sol";

/// @notice ArShield template contract
/// @dev this contract can have (1) underlying asset (2) ether (3) somewhat reward token that is rewarded through reward pool(optional)
abstract contract ArShield {
    using SafeERC20 for IERC20;

    IERC20 public asset;

    IArmorMaster public armorMaster;

    uint256 internal _totalSupply;

    // for ERC20 specs
    string public name;

    string public symbol;

    uint8 public constant decimals = 18;

    mapping(address => uint256) internal balances;
   
    uint256 public weiPerToken;

    modifier checkCoverage(uint256 _amount) {
        // check if plan can cover amount
        _;
    }

    // to get the claim payout
    receive() external payable {
    }

    function initialize(address _master, address _asset) external {
        require(address(asset) == address(0) && _asset != address(0), "already initialized");
        asset = IERC20(_asset);
        armorMaster = IArmorMaster(_master);
        // should do something like this, but skipping now for clarity
        //name = abi.encodePacked("Shielded-", strategy(), asset.name());
        //symbol = abi.encodePacked("Ar-", strategy(), asset.symbol());
    }

    function totalSupply() public view returns(uint256 supply) {
        supply = _totalSupply;
    }
    
    /// @dev deposits asset and recieve Ar-Asset
    /// @param amount amount of asset to be deposited to ArShield
    function deposit(uint256 amount) external returns(uint256 arAmount){
        arAmount = (amount * 1e18) / value();
        _mint(msg.sender, arAmount);
        asset.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @dev withdraws asset by unwrapping Ar-Asset
    /// @param amount of Ar-Asset 
    function withdraw(uint256 amount) external returns(uint256 assetAmount) {
        assetAmount = (amount * value()) / 1e18;
        _burn(msg.sender, amount);
        asset.safeTransfer(msg.sender, assetAmount);
        // send redeemed ether to msg.sender
        if(weiPerToken != 0){
            msg.sender.transfer((weiPerToken * amount) / 1e18);
        }
    }

    /// @dev value of 1(*1e18) Ar-Asset token compared to underlying asset
    function value() public view returns(uint256){
        if(totalSupply() == 0) {
            return 1e18;
        } else {
            return (aum() * 1e18) / totalSupply();
        }
    }

    function balanceOf(address _user) public returns(uint256) {
        return balances[_user];
    }

    function _mint(address _user, uint256 _amount) internal {
        _totalSupply += _amount;
        balances[msg.sender] += _amount;
    }

    function _burn(address _user, uint256 _amount) internal {
        _totalSupply -= _amount;
        balances[msg.sender] -= _amount;
    }

    function liquidate() external {
        address token = tokenToLiquidate();
        //sell token for eth to pay the bill
        uint256 amount = liquidatableAmount();
        sellToken(token, amount);
        supplyBalance();
        updateCoverage();
    }

    /// @dev supply eth owned by this contract to BalanceManager
    function supplyBalance() internal {
        IBalanceManager(armorMaster.getModule("BALANCE")).deposit{value: address(this).balance}( address(0) );
    }

    /// @dev update plan to cover whole supplied asset to protocol
    /// TODO: what if duration is very short???
    function updateCoverage() internal {
        address[] memory protocols = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        protocols[0] = protocol();
        amounts[0] = suppliedAssets();
        IPlanManager(armorMaster.getModule("PLAN")).updatePlan(protocols, amounts);
    }
    
    /// @dev end plan to prepare for the claim
    function endCoverage() internal {
        address[] memory protocols = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        IPlanManager(armorMaster.getModule("PLAN")).updatePlan(protocols, amounts);
    }

    /// @dev function to check if protocol is hacked using claimManager
    function claimCoverage(uint256 _hackTime, uint256 _amount) external {
        endCoverage();
        // There shouldn't ever be an Ether balance in here but just in case there is...
        uint256 startBalance = address(this).balance;

        IClaimManager(armorMaster.getModule("CLAIM")).redeemClaim(protocol(), _hackTime, _amount);
        if (address(this).balance > startBalance) {
            weiPerToken = address(this).balance * 1e18 / totalSupply();
        }
    }
    
    /// ---- functions to be implemented when using this template ---- ///
    function sellToken(address token, uint256 amount) internal virtual;

    /// ---- view functions needs to be implemented to get correct values ---- ///
    /// @dev should represent whole amount of asset under arShield's management
    function aum() public virtual view returns(uint256);

    function liquidatableAmount() public virtual view returns(uint256);

    function tokenToLiquidate() public virtual view returns(address);

    function suppliedAssets() public virtual view returns(uint256);
   
    /// ---- view functions for protocol metadata ---- ///
    /// @dev protocol address this needs to be listed on nexus mutual
    function protocol() public virtual view returns(address);

    /// @dev ex. LP, staking, farming, ...
    function strategy() public virtual pure returns(string memory);
}
