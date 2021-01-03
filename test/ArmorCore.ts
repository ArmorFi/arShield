import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";

export class ArmorCore {
  deployer: Signer;
  rewardToken: Contract;

  master: Contract;
  balanceManager: Contract;
  claimManager: Contract;
  planManager: Contract;
  rewardManager: Contract;
  stakeManager: Contract;

  arNft: Contract;

  constructor(deployer: Signer) {
    this.deployer = deployer;
  }

  async deploy(rewardToken: Contract) {
    const Master = await ethers.getContractFactory("ArmorMaster");
    this.master = await Master.connect(this.deployer).deploy();
    await this.master.initialize();

    const Balance = await ethers.getContractFactory("BalanceManager");
    this.balanceManager = await Balance.connect(this.deployer).deploy();
    await this.balanceManager.initialize(this.master.address, this.deployer.getAddress());
    await this.registerModule("BALANCE", this.balanceManager);
    
    const Claim = await ethers.getContractFactory("ClaimManager");
    this.claimManager = await Claim.connect(this.deployer).deploy();
    await this.claimManager.initialize(this.master.address);
    await this.registerModule("CLAIM", this.claimManager);
    
    const Plan = await ethers.getContractFactory("PlanManager");
    this.planManager = await Plan.connect(this.deployer).deploy();
    await this.planManager.initialize(this.master.address);
    await this.registerModule("PLAN", this.planManager);
    
    const Reward = await ethers.getContractFactory("RewardManager");
    this.rewardManager = await Reward.connect(this.deployer).deploy();
    await this.rewardManager.initialize(this.master.address, rewardToken.address, this.deployer.getAddress());
    await this.registerModule("REWARD", this.rewardManager);
    
    const Stake = await ethers.getContractFactory("StakeManager");
    this.stakeManager = await Stake.connect(this.deployer).deploy();
    await this.stakeManager.initialize(this.master.address);
    await this.registerModule("STAKE", this.stakeManager);
    
    const ArNFT = await ethers.getContractFactory("arNFTMock");
    this.arNft = await ArNFT.connect(this.deployer).deploy();
    await this.registerModule("ARNFT", this.arNft);

    await this.master.connect(this.deployer).addJob(ethers.utils.formatBytes32String("STAKE"));
  }

  async registerModule(key: string, contract: Contract) {
    await this.master.connect(this.deployer).registerModule(ethers.utils.formatBytes32String(key), contract.address);
  }
}
