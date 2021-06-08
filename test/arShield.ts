import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import { increase, getTimestamp } from "./utils";
import { Address } from "ethereumjs-util";
import { hasUncaughtExceptionCaptureCallback } from "process";
const ETHER = BigNumber.from("1000000000000000000");

describe("arShield", function () {
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

  // mock yearn and mock oracle? Probably best

  beforeEach(async function() {
    accounts = await ethers.getSigners();
    gov = accounts[0];
    user = accounts[1];

    const CONTROLLER = await ethers.getContractFactory("ShieldController");
    controller = await CONTROLLER.deploy();
    const SHIELD = await ethers.getContractFactory("arShield");
    masterCopy = await SHIELD.deploy();
    const COVBASE = await ethers.getContractFactory("CoverageBase");
    covBase = await COVBASE.deploy(controller.address);
    //const ORACLE = await ethers.getContractFactory("YearnOracle");
    const ORACLE = await ethers.getContractFactory("MockYearn");
    oracle = await ORACLE.deploy();
    const PTOKEN = await ethers.getContractFactory("ERC20");
    pToken = await PTOKEN.deploy("yDAI","Yearn DAI");
    await pToken.connect(gov).transfer(user.getAddress(), ETHER.mul(100000));
    // Not needed for these tests so making it a random address.
    uTokenLink = oracle.address;

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

  describe("#mint", function () {

    beforeEach(async function() {
      await pToken.approve( arShield.address, ETHER.mul(100000) );
      await pToken.connect(user).approve( arShield.address, ETHER.mul(100000) );
      await arShield.mint(ETHER.mul(1000));
    });

      it("should increase total fees to liquidate", async function(){
        let totalFees = await arShield.totalLiqAmts();
        expect(totalFees).to.be.equal( ETHER.mul(25).div(10) );
      });

      it("should mint 1:1 with no pTokens in contract", async function(){
        let balance = await arToken.balanceOf( gov.getAddress() );
        expect(balance).to.be.equal(ETHER.mul(9975).div(10));
      });
      
      it("should mint correctly with pTokens in contract", async function(){
        await arShield.connect(user).mint( ETHER.mul(1000) );

        let userAr = await arToken.balanceOf( user.getAddress() );
        expect(userAr).to.be.equal(ETHER.mul(9975).div(10));

        let shieldBal = await pToken.balanceOf( arShield.address );
        expect(shieldBal).to.be.equal( ETHER.mul(2000) );
      });

  });

  describe("#redeem", function () {

    beforeEach(async function() {
      await pToken.approve( arShield.address, ETHER.mul(100000) );
      await pToken.connect(user).approve( arShield.address, ETHER.mul(100000) );
      await arShield.connect(gov).mint(ETHER.mul(1000));
      await arToken.approve( arShield.address, ETHER.mul(100000) );
    });

      it("should redeem extra pTokens in contract", async function(){
        let balance = await pToken.balanceOf( gov.getAddress() );
        await arShield.redeem(ETHER.mul(975));
        balance = await pToken.balanceOf( gov.getAddress() );
        // expect artoken balance is 0
        // expect ptoken balance is whatever
      });

      it("should redeem last pTokens from contract", async function(){

      });

  });

  // describe: liquidation

    // liqAmts
    // payAmts
    // deposit update
    // multiple cov bases

  // describe: notify hack and claim

    // notifyHack
    // confirmHack
    // claim
    // unlock
    // ban payouts

  describe("#miscellaneous", function () {

    beforeEach(async function() {
      await pToken.approve( arShield.address, ETHER.mul(100000) );
      await pToken.connect(user).approve( arShield.address, ETHER.mul(100000) );
      await arShield.mint(ETHER.mul(1000));
      await arToken.approve( arShield.address, ETHER.mul(100000) );
    });

      it("should be able to change fees", async function(){

      });

      it("should be able to withdraw excess", async function(){

      });

  });

  // multiple cov base differences

});
