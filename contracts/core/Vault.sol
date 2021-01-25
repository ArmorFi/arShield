
contract Vault {
    IERC20 public lpToken;

    uint256 public totalStaked;

    mapping(address => uint256) balanceOf;
    function deposit(uint256 amount) external {
        totalStaked += amount;
        _mint(msg.sender, totalSupply() * amount / totalStaked);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, totalSupply() * amount / totalStaked);
        totalStaked -= amount;
    }
}
