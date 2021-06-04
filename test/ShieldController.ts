import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import { increase, getTimestamp } from "./utils";
import { Address } from "ethereumjs-util";
const ETHER = BigNumber.from("1000000000000000000");

describe("ShieldController", function () {
  let accounts: Signer[];
  let gov : Signer;
  let user : Signer;
  let arToken: Contract;
  let pToken: Contract;
  let masterCopy: Contract;
  let controller: Contract;
  let oracle: Contract;
  let covBase: Contract;
  let uTokenLink: String;
  let arShield: Contract;

  beforeEach(async function() {
    accounts = await ethers.getSigners();
    gov = accounts[0];
    user = accounts[1];

    const CONTROLLER = await ethers.getContractFactory("ShieldController");
    controller = await CONTROLLER.deploy();
    const SHIELD = await ethers.getContractFactory("arShield");
    // This is mastercopy
    masterCopy = await SHIELD.deploy();
    const COVBASE = await ethers.getContractFactory("CoverageBase");
    covBase = await COVBASE.deploy(controller.address);
    const ORACLE = await ethers.getContractFactory("YearnOracle");
    oracle = await ORACLE.deploy();
    const PTOKEN = await ethers.getContractFactory("ERC20");
    pToken = await PTOKEN.deploy("yDAI","Yearn DAI");
    // Not needed for these tests so making it a random address.
    uTokenLink = oracle.address;
  });

  describe("#createShield", function () {

    beforeEach(async function() {
      await controller.connect(gov).createShield("Armor yDAI", 
                                                 "armorYDAI", 
                                                 masterCopy.address, 
                                                 pToken.address,
                                                 uTokenLink,
                                                 oracle.address,
                                                 [covBase.address],
                                                 [25]
                                                );
      
      let shields = await controller.getShields();
      let shieldAddress = shields[0];
      arShield = await ethers.getContractAt("arShield", shieldAddress);

      let arTokenAddress = await arShield.arToken();
      arToken = await ethers.getContractAt("IArmorToken", arTokenAddress);
    });

      it("should launch token with correct values", async function(){
        let name = await arToken.name();
        let symbol = await arToken.symbol();
        console.log(name);
      });

      it("should launch shield with correct values", async function(){
        //expect(await varmor.totalSupply()).to.equal(0);
      });

      it("should add shield to Coverage Base", async function(){
        //expect(await varmor.totalSupply()).to.equal(0);
      });

      it("should add shield to arShields list", async function(){
        //expect(await varmor.totalSupply()).to.equal(0);
      });

      it("should add sender as governor", async function(){
        //expect(await varmor.totalSupply()).to.equal(0);
      });

      it("should transfer proxy ownership to sender", async function(){
        //expect(await varmor.totalSupply()).to.equal(0);
      });

    // chaing bonus

    // change deposit amounts

    // getShields
    
    // delete shield

  });

});
