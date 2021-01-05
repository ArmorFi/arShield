import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import { Uniswap } from "./Uniswap";
import { ArmorCore } from "./ArmorCore";
import { increase } from "./utils";
const ETHER = BigNumber.from("1000000000000000000");
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
    
    await weth.deposit({value:ETHER.mul(100)});
    await uniswap.supply(token0, token1, ETHER.mul(100),ETHER.mul(100));
    await uniswap.supply(token0, weth, ETHER.mul(2),ETHER.mul(2));
    await uniswap.supply(weth, token1, ETHER.mul(2),ETHER.mul(2));
    armorReward = await Token.connect(owner).deploy();
    core = new ArmorCore(owner);
    await core.deploy(armorReward);

    const Shield = await ethers.getContractFactory("ArShieldLP");
    arShield = await Shield.deploy([token0.address, token1.address],[token0.address, weth.address], [token1.address, weth.address],
      core.master.address,uniswap.router.address,lpToken.address,reward.address,BigNumber.from("1000"),1,uniswap.router.address,ETHER
    );
  });

  describe("#stake()", function(){
    it("should fail if coverage is not enough", async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(1));
      await lpToken.approve(arShield.address, constants.MaxUint256);;
      await expect(arShield.connect(owner).stake(ETHER.mul(2),constants.AddressZero)).to.be.revertedWith("Not enough coverage available for this stake.");
    });
    it("should be able to stake", async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(10000));
      await lpToken.approve(arShield.address, constants.MaxUint256);;
      await arShield.connect(owner).stake(ETHER,constants.AddressZero);
    });
  });

  describe('#liquidate()', function(){
    beforeEach(async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(10000));
      await lpToken.approve(arShield.address, constants.MaxUint256);;
      await arShield.connect(owner).stake(ETHER,constants.AddressZero);
      await increase(1000000);
      await arShield.connect(owner).stake(ETHER,constants.AddressZero);
    });

    it("should fail if msg.sender is not eoa", async function(){
      const MockCaller = await ethers.getContractFactory("MockCaller");
      const caller = await MockCaller.deploy();
      await expect(caller.execute(arShield.address, "liquidate()", "0x")).to.be.reverted;
    });

    it("should be able to liquidate", async function(){
      await arShield.connect(owner).liquidate();
    });
  });
});
