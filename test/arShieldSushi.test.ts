import { expect } from "chai";
import { ethers } from "hardhat";
import { providers, Contract, Signer, BigNumber, constants } from "ethers";
import { Uniswap } from "./Uniswap";
import { ArmorCore } from "./ArmorCore";
import { increase, getTimestamp } from "./utils";
const ETHER = BigNumber.from("1000000000000000000");
describe.only("ArShieldSushi", function () {
  let accounts: Signer[];
  let uniswap: Uniswap;
  let masterChef: Contract;
  let weth: Contract;
  let sushi: Contract;
  let owner : Signer;
  let user : Signer;
  let referrer : Signer;
  let dev : Signer;
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
    referrer = accounts[2];
    dev = accounts[3];
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

    const Sushi = await ethers.getContractFactory("SushiToken");
    sushi = await Sushi.deploy();
    const startRewardBlock = BigNumber.from(await (owner.provider as providers.JsonRpcProvider).send("eth_blockNumber", []));
    const endRewardBlock = startRewardBlock.mul(100);
    const MasterChef = await ethers.getContractFactory("MasterChef");
    masterChef = await MasterChef.deploy(sushi.address, dev.getAddress(), ETHER,startRewardBlock, endRewardBlock);
    await sushi.transferOwnership(masterChef.address);
    await masterChef.add(100, lpToken.address, false);
    const Shield = await ethers.getContractFactory("ArShieldSushi");
    arShield = await Shield.deploy([token0.address, token1.address],[token0.address, weth.address], [token1.address, weth.address],
      core.master.address,uniswap.router.address,0,reward.address,ETHER/*BigNumber.from("1000")*/,10,uniswap.router.address,ETHER,masterChef.address
    );
  });

  describe("#stake()", function(){
    it("should fail if coverage is not enough", async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(1));
      await lpToken.approve(arShield.address, constants.MaxUint256);
      await expect(arShield.connect(owner).stake(ETHER.mul(2),referrer.getAddress())).to.be.revertedWith("Not enough coverage available for this stake.");
    });
    it("should be able to stake", async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await lpToken.approve(arShield.address, constants.MaxUint256);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
    });
    it("should fail if locked", async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await lpToken.approve(arShield.address, constants.MaxUint256);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(100);
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(10);
      await arShield.liquidate();
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(50);
      const time = await getTimestamp();
      await core.hacked(uniswap.router, time.sub(1));
      await arShield.claimCoverage(time.sub(1),1);
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await expect(arShield.connect(owner).stake(ETHER,referrer.getAddress())).to.be.reverted;
    });
    it("should decrease balance based on feePercent and increase stake", async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await lpToken.approve(arShield.address, constants.MaxUint256);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(50);
      const before = await arShield.balanceOf(owner.getAddress());
      const fee = before.div(2);
      const referFee = fee.div(100);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      const after = await arShield.balanceOf(owner.getAddress());
      expect(after).to.be.equal(before.sub(fee).add(ETHER));
      expect(fee.sub(referFee)).to.be.equal(await arShield.feePool());
      expect(await arShield.referralBalances(referrer.getAddress())).to.equal(referFee);
    });
    it("should clear balance if percent more than 100%", async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await lpToken.approve(arShield.address, constants.MaxUint256);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(1000);
      const before = await arShield.balanceOf(owner.getAddress());
      const fee = before;
      const referFee = fee.div(100);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      const after = await arShield.balanceOf(owner.getAddress());
      expect(after).to.be.equal(before.sub(fee).add(ETHER));
      expect(fee.sub(referFee)).to.be.equal(await arShield.feePool());
      expect(await arShield.referralBalances(referrer.getAddress())).to.equal(referFee);
    });
  });

  describe('#liquidate()', function(){
    beforeEach(async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await lpToken.approve(arShield.address, constants.MaxUint256);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(1000000);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
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

  describe('#withdraw()', function(){
    beforeEach(async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await lpToken.approve(arShield.address, constants.MaxUint256);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(10);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await arShield.connect(owner).liquidate();
    });

    it("should success", async function(){
      await arShield.connect(owner).withdraw(ETHER);
    });
    it("can withdraw even hack", async function(){  
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await lpToken.approve(arShield.address, constants.MaxUint256);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(100);
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(10);
      await arShield.liquidate();
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(50);
      const time = await getTimestamp();
      await core.hacked(uniswap.router, time.sub(1));
      //await arShield.liquidate();
      await arShield.claimCoverage(time.sub(1),1);
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await arShield.connect(owner).withdraw(ETHER.div(10));
    });
  });

  describe('#exit()', function(){
    beforeEach(async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await lpToken.approve(arShield.address, constants.MaxUint256);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(1000000);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await arShield.connect(owner).liquidate();
    });
    
    it("should success", async function(){
      await arShield.connect(owner).exit();
    });
    it("can exit even with hack", async function(){
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await lpToken.approve(arShield.address, constants.MaxUint256);
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(100);
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(10);
      await arShield.liquidate();
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await arShield.connect(owner).stake(ETHER,referrer.getAddress());
      await increase(50);
      const time = await getTimestamp();
      await core.hacked(uniswap.router, time.sub(1));
      //await arShield.liquidate();
      await arShield.claimCoverage(time.sub(1),1);
      await core.increaseStake(uniswap.router, BigNumber.from(50));
      await arShield.connect(owner).exit();
    });
  });
});
