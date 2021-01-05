import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import { Uniswap } from "./Uniswap";
import { ArmorCore } from "./ArmorCore";
describe("ArShield", function () {
  let accounts: Signer[];
  let uniswap: Uniswap;
  let weth: Contract;
  let owner : Signer;
  let user : Signer;
  let lpToken : Contract;
  let token0: Contract;
  let token1: Contract;

  let reward: Contract;
  let arShield: Contract;

  let core: ArmorCore;
  let armorReward: Contract;
  beforeEach(async function () {
    accounts = await ethers.getSigners();
    owner = accounts[0];
    user = accounts[1];
    const WETH = await ethers.getContractFactory("WETH9");
    weth = await WETH.deploy();
    const Token = await ethers.getContractFactory("ERC20Mock");
    token0 = await Token.connect(owner).deploy();
    token1 = await Token.connect(owner).deploy();
    reward = await Token.connect(owner).deploy();
    uniswap = new Uniswap(owner);
    await uniswap.deploy(weth);
    lpToken = await uniswap.createPair(token0, token1);
    await uniswap.createPair(weth, token1);
    await uniswap.createPair(token0, weth);
    console.log(lpToken.address);
    await uniswap.supply(token0, token1, 1000000000,1000000000);
    await uniswap.supply(token0, weth, 1000000000,1000000000);
    await uniswap.supply(weth, token1, 1000000000,1000000000);

    armorReward = await Token.connect(owner).deploy();
    core = new ArmorCore(owner);
    await core.deploy(armorReward);

    const Shield = await ethers.getContractFactory("ArShieldLP");
    arShield = await Shield.deploy([token0.address, token1.address],[token0.address, weth.address], [token1.address, weth.address],
      core.master.address,uniswap.router.address,lpToken.address,reward.address,1,1,uniswap.router.address,1
    );
  });

  describe("#stake()", function(){
    it("should fail if coverage is not enough", async function(){
    });
    it("should be able to stake", async function(){
      await core.increaseStake(uniswap.router, 1000);
      await lpToken.approve(arShield.address, 1000);
      await arShield.connect(owner).stake(1000,constants.AddressZero);
      await arShield.connect(owner).liquidate();
    });
  });
});
