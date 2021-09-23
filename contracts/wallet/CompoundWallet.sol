// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract CompoundWallet {
    address constant public WETH = address(0);

    address public owner;

    address public arShieldCompoundController;

    constructor(address _owner) {
        owner = _owner;
    }

    function withdraw(address _token, uint256 _amount) external {
        require(msg.sender == owner, "!owner");
        address cToken = arShieldCompoundController.getCToken(_token);
        if(_token != ETH){
            uint256 res = ICToken(cToken).redeemUnderlying(_amount);
            require(res == 0, "error while redeeming");
            IERC20(_token).transfer(msg.sender, _amount);
        } else {
            uint256 res = ICEther(cToken).borrow(_amount);
            require(res == 0, "error while redeeming");
            msg.sender.call{value:_amount}();
        }
        sync(cToken);
    }

    function borrow(address _token, uint256 _amount) external {
        require(msg.sender == owner, "!owner");
        address cToken = arShieldCompoundController.getCToken(_token);
        if(_token != ETH){
            uint256 res = ICToken(cToken).borrow(_amount);
            require(res == 0, "error while borrowing");
            IERC20(_token).transfer(msg.sender, _amount);
        } else {
            uint256 res = ICEther(cToken).borrow(_amount);
            require(res == 0, "error while borrowing");
            msg.sender.call{value:_amount}();
        }
        sync(cToken);
    }

    function authorizedTransfer(address _to, uint256 _amount) external {
        require(arShieldCompoundController.isArToken(msg.sender), "!arToken");
        IERC20(IARToken(msg.sender).cToken()).transfer(_to, _amount);
    }

    function sync(address _ctoken) public {
        IERC20 cToken = IERC20(_cToken);
        IARToken arToken = arShieldCompoundController.getArToken(_cToken);
        uint256 arBalance = arToken.balanceOf(owner);
        uint256 cBalance = cToken.balanceOf(address(this));
        if(arBalance < cBalance) {
            arToken.mint(cBalance - arBalance);
        } else if (arBalance > cBalance) {
            arToken.burn(arBalance - cBalance);
        }
    }
}
