import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import UniswapV2Factory from '@uniswap/v2-core/build/UniswapV2Factory.json';
export class Uniswap {
  deployer: Signer;
  router: Contract;
  factory: Contract;
  weth: Contract;

  constructor(deployer: Signer) {
    this.deployer = deployer;
  }

  async deploy(weth: Contract) {
    this.weth = weth;
    const Factory = new ethers.ContractFactory(UniswapV2Factory.interface, UniswapV2Factory.bytecode, this.deployer);
    const Router = await ethers.getContractFactory("UniswapV2Router02");

    this.factory = await Factory.deploy(this.deployer.getAddress());
    await this.factory.setFeeTo(this.deployer.getAddress());

    this.router = await Router.deploy(this.factory.address, weth.address);
  }

  async createPair(token0: Contract, token1: Contract) : Promise<Contract>{
    await this.factory.createPair(token0.address, token1.address);
    return await this.getPair(token0, token1);
  }

  async getPair(token0: Contract, token1: Contract) : Promise<Contract> {
    const addr = await this.factory.getPair(token0.address, token1.address);
    const Pair = await ethers.getContractFactory("UniswapV2Pair");
    return await Pair.attach(addr);
  }

  async supply(token0: Contract, token1: Contract, amount0: number, amount1: number) {
    await token0.connect(this.deployer).approve(this.router.address, constants.MaxUint256);
    await token1.connect(this.deployer).approve(this.router.address, constants.MaxUint256);
    await this.router.addLiquidity(token0.address, token1.address, amount0,amount1, 1,1, this.deployer.getAddress(), constants.MaxUint256);
  }
}
