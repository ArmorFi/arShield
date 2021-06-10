import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import { increase, getTimestamp } from "./utils";
import { Address } from "ethereumjs-util";
import { hasUncaughtExceptionCaptureCallback } from "process";
const ETHER = BigNumber.from("1000000000000000000");
const ZERO_ADDY = "0x0000000000000000000000000000000000000000";

describe("arShield", function () {
  let accounts: Signer[];
  let gov : Signer;
  let user : Signer;
  let referrer : Signer;
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
    referrer = accounts[2];

    const CONTROLLER = await ethers.getContractFactory("ShieldController");
    controller = await CONTROLLER.deploy(50, 10000, ETHER.mul(10));
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

      it("estimate cost", async function(){
        let pendingMint = arShield.connect(user).mint( ETHER.mul(1000) );
        let estimate = await user.estimateGas(pendingMint)
        console.log(estimate.toString());
      });
      
      it("should mint correctly with pTokens in contract", async function(){
        await arShield.connect(user).mint( ETHER.mul(1000) );

        let userAr = await arToken.balanceOf( user.getAddress() );
        expect(userAr).to.be.equal(ETHER.mul(9975).div(10));

        let shieldBal = await pToken.balanceOf( arShield.address );
        expect(shieldBal).to.be.equal( ETHER.mul(2000) );
      });

  });

  describe.only("#redeem", function () {

    beforeEach(async function() {
      await pToken.approve( arShield.address, ETHER.mul(100000) );
      await pToken.connect(user).approve( arShield.address, ETHER.mul(100000) );
      await arShield.connect(gov).mint(ETHER.mul(1000), ZERO_ADDY);
      await arToken.approve( arShield.address, ETHER.mul(100000) );
    });

      it("should redeem last pTokens in contract", async function(){
        let balance = await pToken.balanceOf( gov.getAddress() );
        let arBal = await arToken.balanceOf( gov.getAddress() );
        
        await arShield.redeem(arBal);
        
        let endBal = await pToken.balanceOf( gov.getAddress() );
        let arBalance = await arToken.balanceOf( gov.getAddress() );
        expect(arBalance).to.be.equal(0);
        let diff = endBal.sub(balance);

        // Kinda confusing to get to this number because of liquidator bonus:
        // mint protocol fees: 1000 * 0.0025
        // mint referral fees: 1000 * 0.0025
        // mint liq bonus fees: mint protocol fees * 0.005
        // full mint: 1000 * 0.005 + (1000 * 0.0025 * 0.005)

        // subtract mint fees and you get 994.9875, repeat the above on that for redeem.
        expect(diff).to.be.equal("990000125156250000000");
      });
      
      it("should redeem extra pTokens from contract", async function(){
        await arShield.connect(user).mint(ETHER.mul(1000), ZERO_ADDY);
        let balance = await pToken.balanceOf( user.getAddress() );
        let arBal = await arToken.balanceOf( user.getAddress() );

        await arToken.connect(user).approve( arShield.address, ETHER.mul(100000) );
        await arShield.connect(user).redeem(arBal);
        
        let endBal = await pToken.balanceOf( user.getAddress() );
        let arBalance = await arToken.balanceOf( user.getAddress() );
        expect(arBalance).to.be.equal(0);
        
        let diff = endBal.sub(balance);
        expect(diff).to.be.equal("990000125156250000000");

        let pBal = await pToken.balanceOf(arShield.address);
        console.log(pBal.toString());
      });

  });

  describe("#liquidate", function () {

    beforeEach(async function() {
      await pToken.approve( arShield.address, ETHER.mul(100000) );
      await arShield.mint(ETHER.mul(1000), ZERO_ADDY);
      await pToken.connect(user).approve( arShield.address, ETHER.mul(1000) );
    });
    
      it("should return correct amount on liqAmts", async function() {

      });

      it("should return correct amounts on payAmts", async function() {

      });

      it("should update and deposit on cov base", async function() {

      });

      it("should work with multiple cov bases", async function() {

      });

  });

  describe("#hack", function () {

    beforeEach(async function() {
      await pToken.approve( arShield.address, ETHER.mul(100000) );
      await arShield.mint(ETHER.mul(1000), ZERO_ADDY);
      await pToken.connect(user).approve( arShield.address, ETHER.mul(1000) );
    });
    
      it("should pause upon correct deposit and set correct variables", async function() {

      });

      it("should set correct variables upon confirmation", async function() {

      });

      it("should be able to ban payouts from users", async function() {

      });

      it("should be able to claim funds", async function() {

      });
  
      it("should be able to unlock contract", async function() {

      });

  });

  describe("#referrals", function () {

    beforeEach(async function() {
      await pToken.approve( arShield.address, ETHER.mul(100000) );
      await arShield.mint(ETHER.mul(1000), ZERO_ADDY);
      await pToken.connect(user).approve( arShield.address, ETHER.mul(1000) );
    });
    
      // fee is currently set to 100% of protocol fee, so should be 0.25%.
      it("should charge correct amount", async function() {
        let refBal = await arShield.refBals(gov.getAddress());
        expect(refBal).to.be.equal("2500000000000000000")
      });

      it("should give referral to correct user", async function() {
        await arShield.connect(user).mint( ETHER.mul(1000), referrer.getAddress() );
        let ref = await arShield.referrers( user.getAddress() );
        expect(ref).to.be.equal( await referrer.getAddress() );
      });

      it("should be able to withdraw", async function() {
        let bal = await pToken.balanceOf( gov.getAddress() );
        await arShield.withdraw( gov.getAddress() );
        let endBal = await pToken.balanceOf( gov.getAddress() );
        expect(endBal).to.be.equal( bal.add("2500000000000000000") )
      });
  
  });

  describe("#miscellaneous", function () {

    it("should be able to change fees", async function() {
      await arShield.connect(gov).changeFees([50]);
      let fee = await arShield.feePerBase(0);
      expect(fee).to.be.equal(50);
    });

    it("should be able to withdraw excess", async function() {
      await gov.sendTransaction( {'to':arShield.address, 'value':ETHER} );
      let balance = await gov.getBalance();
      await arShield.withdrawExcess( ZERO_ADDY, gov.getAddress() );
      let endBal = await gov.getBalance();
      // pain to account for gas
      expect(endBal).to.not.equal(balance);

      await arToken.transfer( arShield.address, ETHER.mul(100) );
      balance = await arToken.balanceOf( gov.getAddress() );
      await arShield.withdrawExcess( arToken.address, gov.getAddress() );
      endBal = await arToken.balanceOf( gov.getAddress() );
      expect(endBal).to.be.equal( balance.add( ETHER.mul(100) ) );
    });

  });

  // multiple cov base differences

});