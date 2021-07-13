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
    await controller.initialize(50, 10000, ETHER.mul(10));
    const SHIELD = await ethers.getContractFactory("arShield");
    masterCopy = await SHIELD.deploy();
    const COVBASE = await ethers.getContractFactory("CoverageBase");
    covBase = await COVBASE.deploy();
    await covBase.initialize(controller.address, controller.address, 5000);
    const ORACLE = await ethers.getContractFactory("YearnOracle");
    oracle = await ORACLE.deploy();
    const PTOKEN = await ethers.getContractFactory("ERC20");
    pToken = await PTOKEN.deploy("yDAI","Yearn DAI");
    // Not needed for these tests so making it a random address.
    uTokenLink = oracle.address;
  });

  describe("#createShield", function () {

    beforeEach(async function() {
      await controller.connect(gov).createShield(
        "Armor yDAI",
        "armorYDAI",
        oracle.address,
        pToken.address,
        uTokenLink,
        masterCopy.address,
        [25],
        [covBase.address]
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
        expect(name).to.be.equal("Armor yDAI");
        expect(symbol).to.be.equal("armorYDAI");
      });

      it("should not create shield for rando", async function(){
        await expect(controller.connect(user).createShield(
          "Armor yDAI",
          "armorYDAI",
          oracle.address,
          pToken.address,
          uTokenLink,
          masterCopy.address,
          [25],
          [covBase.address]
        )
        ).to.be.revertedWith("msg.sender is not owner");
      });

      it("should launch shield with correct values", async function(){
        let feesToLiq2 = await arShield.feesToLiq(0);
        let feePerBase2 = await arShield.feePerBase(0);
        let uTokenLink2 = await arShield.uTokenLink();
        let arToken2 = await arShield.arToken();
        let controller2 = await arShield.controller();
        let oracle2 = await arShield.oracle();
        let pToken2 = await arShield.pToken();
        let covBases2 = await arShield.covBases(0);
        
        expect(feesToLiq2).to.be.equal(0);
        expect(feePerBase2).to.be.equal(25);
        expect(uTokenLink2).to.be.equal(uTokenLink);
        expect(arToken2).to.be.equal(arToken.address);
        expect(controller2).to.be.equal(controller.address);
        expect(oracle2).to.be.equal(oracle.address);
        expect(pToken2).to.be.equal(pToken.address);
        expect(covBases2).to.be.equal(covBase.address);
      });

      it("should add shield to Coverage Base", async function(){
        let shield = await covBase.shieldStats(arShield.address);
        expect( parseInt(shield.lastUpdate) ).to.be.greaterThan(0);
      });

      it("should add shield to arShields list", async function(){
        let shields = await controller.getShields();
        expect(shields[0]).to.be.equal(arShield.address);
      });

      it("should add sender as governor", async function(){
        let governor = await controller.governor();
        expect(governor).to.be.equal( await gov.getAddress() );
      });

      it("should transfer Shield proxy ownership to sender", async function(){
        let proxyShield = await ethers.getContractAt("OwnedUpgradeabilityProxy", arShield.address);
        let proxyOwner = await proxyShield.proxyOwner();
        expect(proxyOwner).to.be.equal( await gov.getAddress() );
      });

  });

  describe("misc. functions", function () {

    it("should change bonus", async function(){
      let oldBonus = await controller.bonus();
      expect(oldBonus).to.be.equal(50);
      await controller.connect(gov).changeBonus(100);
      let newBonus = await controller.bonus();
      expect(newBonus).to.be.equal(100);
    });

    it("should not change bonus for rando", async function(){
      await expect(controller.connect(user).changeBonus(50)).to.be.revertedWith("msg.sender is not owner");
    });

    it("should change deposit amount", async function(){
      let oldAmt = await controller.depositAmt();
      expect(oldAmt).to.be.equal(ETHER.mul(10));
      await controller.connect(gov).changeDepositAmt( ETHER.mul(5) );
      let newAmt = await controller.depositAmt();
      expect(newAmt).to.be.equal(ETHER.mul(5));
    });

    it("should not change deposit amount for rando", async function(){
      await expect(controller.connect(user).changeDepositAmt(ETHER.mul(5))).to.be.revertedWith("msg.sender is not owner");
    });

    it("should get array of shields", async function(){
      await controller.connect(gov).createShield("Armor yDAI", 
                                                 "armorYDAI", 
                                                 oracle.address,
                                                 pToken.address,
                                                 uTokenLink,
                                                 masterCopy.address, 
                                                 [25],
                                                 [covBase.address]
                                                );
      
      let shields = await controller.getShields();
      let shieldAddress = shields[0];
    });

    it("should delete shield", async function(){
      await controller.connect(gov).createShield("Armor yDAI", 
                                                 "armorYDAI", 
                                                 oracle.address,
                                                 pToken.address,
                                                 uTokenLink,
                                                 masterCopy.address, 
                                                 [25],
                                                 [covBase.address]
                                                );
      let shields = await controller.getShields();
      let shieldAddress = shields[0];
      await controller.connect(gov).deleteShield(shieldAddress, 0);

      shields = await controller.getShields();
      expect(shields.length).to.be.equal(0);
    });

    it("should not delete shield for rando", async function(){
      // Using controller address for funsies since the revertedWith is what matters.
      await expect(controller.connect(user).deleteShield(controller.address, 0)).to.be.revertedWith("msg.sender is not owner");
    });
  });

});
