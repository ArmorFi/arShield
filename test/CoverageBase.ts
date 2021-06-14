import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import { increase, getTimestamp, mine } from "./utils";
import { Address } from "ethereumjs-util";
import { hasUncaughtExceptionCaptureCallback } from "process";
const ETHER = BigNumber.from("1000000000000000000");
const ZERO_ADDY = "0x0000000000000000000000000000000000000000";

describe("arShield", function () {
  let accounts: Signer[];
  let gov : Signer;
  let user : Signer;
  let controller: Contract;
  let core: Contract;
  let covBase: Contract;

  // mock yearn and mock oracle? Probably best

  beforeEach(async function() {
    accounts = await ethers.getSigners();
    gov = accounts[0];
    user = accounts[1];

    const CONTROLLER = await ethers.getContractFactory("ShieldController");
    controller = await CONTROLLER.deploy(50, 10000, ETHER.mul(10));
    const COVBASE = await ethers.getContractFactory("TestCoverageBase");
    covBase = await COVBASE.deploy(controller.address, controller.address, 5000);
    const CORE = await ethers.getContractFactory("MockCore");
    core = await CORE.deploy();

    // sets coverage to 1,000,000,000,000 Wei per second
    await covBase.updateCoverage();

    // Set governance to shield
    await covBase.editShield(gov.getAddress(), true);
  });

  describe("#update", function () {
  
    it("should update shield amounts.", async function(){
        await covBase.updateShield(ETHER);
        let stats = await covBase.shieldStats(gov.getAddress());
        console.log(stats.toString());

        let total = await covBase.costPerEth();
        console.log(total.toString());
        increase(10000);

        stats = await covBase.shieldStats(gov.getAddress());
        console.log(stats.toString());

        let poop = await covBase.getShieldOwed(gov.getAddress());
        console.log(poop.toString());
    });

  });

});
