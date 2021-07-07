import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import { increase, getTimestamp, mine } from "./utils";
import { Address } from "ethereumjs-util";
import { hasUncaughtExceptionCaptureCallback } from "process";
const ETHER = BigNumber.from("1000000000000000000");
const ZERO_ADDY = "0x0000000000000000000000000000000000000000";

describe("CoverageBase", function () {
  let accounts: Signer[];
  let gov : Signer;
  let user : Signer;
  let controller: Contract;
  let covBase: Contract;

  beforeEach(async function() {
    accounts = await ethers.getSigners();
    gov = accounts[0];
    user = accounts[1];

    const CONTROLLER = await ethers.getContractFactory("ShieldController");
    controller = await CONTROLLER.deploy(50, 10000, ETHER.mul(10));
    const COVBASE = await ethers.getContractFactory("TestCoverageBase");
    covBase = await COVBASE.deploy(controller.address, controller.address, 5000);

    // Set governance to shield
    await covBase.editShield(gov.getAddress(), true);
    await covBase.editShield(user.getAddress(), true);
  });

  describe("#update", function () {
  
    it("should update shield amounts", async function(){
        // sets coverage to 1,000,000,000,000 Wei per second
        await covBase.updateCoverage("1000000000000");

        await covBase.updateShield(ETHER);
        await covBase.costPerEth();
        await increase(10000);
        await mine();

        await covBase.updateShield(ETHER);
        let stats = await covBase.shieldStats(gov.getAddress());
        // since costPerEth is 1e12, after 10k seconds it should owe 1e16. Then the mine adds 1 extra second.
        expect(stats[3].toString()).to.be.equal("10001000000000000");
        await increase(10000);
        await mine();

        await covBase.getShieldOwed(gov.getAddress());
        await covBase.updateShield(ETHER);
        let stats2 = await covBase.shieldStats(gov.getAddress());
        expect(stats2[3].toString()).to.be.equal("20002000000000000");
    });

    it("should update paid", async function(){
      await covBase.updateCoverage("1000000000000");
      await covBase.updateShield(ETHER);
      increase(10000);
      mine();

      await covBase.getShieldOwed(gov.getAddress());
      await covBase.updateShield(ETHER,{value:ETHER});
      let stats = await covBase.shieldStats(gov.getAddress());
      expect(stats[3].toString()).to.be.equal("0");
    });

    it("should update paid through price changes", async function(){
      await covBase.updateCoverage("1000000000000");
      await covBase.updateShield(ETHER);
      await increase(10000);
      await mine();

      await covBase.updateCoverage("2000000000000");
      await increase(10000);
      await mine();
      
      let owed = await covBase.getShieldOwed( gov.getAddress() );
      expect(owed).to.be.equal("30001000000000000")
    });

    it("should update with multiple shields", async function(){
      await covBase.updateCoverage("1000000000000");
      await covBase.updateShield(ETHER);
      await covBase.connect(user).updateShield(ETHER.mul(2));
      await increase(10000);
      await mine();

      await covBase.updateCoverage("2000000000000");
      await increase(10000);
      await mine();
      
      let govOwed = await covBase.getShieldOwed( gov.getAddress() );
      expect(govOwed).to.be.equal("10001333333323333")
      let userOwed = await covBase.getShieldOwed( user.getAddress() );
      expect(userOwed).to.be.equal("20000666666646666")
    });

  });

  describe("#miscellaneous", function () {

    it("should change cover percent", async function(){
      await covBase.changeCoverPct(10000);
      let pct = await covBase.coverPct();
      expect(pct).to.be.equal(10000);
    });

    it("should disburse to shields", async function(){
      await gov.sendTransaction({'to':covBase.address,'value':ETHER});
      await covBase.disburseClaim(user.getAddress(), ETHER);
    });

  });

});
