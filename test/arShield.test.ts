import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import { Uniswap } from "./Uniswap";
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
  beforeEach(async function () {
    accounts = await ethers.getSigners();
    owner = accounts[0];
    user = accounts[1];
    const WETH = await ethers.getContractFactory("WETH9");
    weth = await WETH.deploy();
    const Token = await ethers.getContractFactory("ERC20Mock");
    token0 = await Token.connect(owner).deploy();
    token1 = await Token.connect(owner).deploy();
    uniswap = new Uniswap(owner);
    await uniswap.deploy(weth);
    lpToken = await uniswap.createPair(token0, token1);
    await uniswap.supply(token0, token1, 1000000000,1000000000);
  });

  it("", async function(){
    console.log("hi");
  });
});
