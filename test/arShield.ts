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
    const COVBASE = await ethers.getContractFactory("MockCovBase");
    covBase = await COVBASE.deploy(controller.address);
    //const ORACLE = await ethers.getContractFactory("YearnOracle");
    const ORACLE = await ethers.getContractFactory("MockYearn");
    oracle = await ORACLE.deploy();
    const PTOKEN = await ethers.getContractFactory("MockERC20");
    pToken = await PTOKEN.deploy("yDAI","Yearn DAI");
    await pToken.connect(gov).mint(ETHER.mul(100000));
    await pToken.connect(gov).mint(ETHER.mul(100000));
    await pToken.connect(gov).transfer(user.getAddress(), ETHER.mul(100000));
    // Not needed for these tests so making it a random address.
    uTokenLink = oracle.address;

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

  describe("#mint", function () {

    beforeEach(async function() {
      await pToken.connect(gov).approve( arShield.address, ETHER.mul(100000) );
      await pToken.connect(user).approve( arShield.address, ETHER.mul(100000) );
      await arShield.connect(gov).mint(ETHER.mul(1000), ZERO_ADDY);
    });

      it("should increase total fees", async function(){
        let totalFees = await arShield.totalFeeAmts();
        // mint fee + ref fee + liquidator bonus
        expect(totalFees).to.be.equal("5012500000000000000");
      });

      it("should mint 1:1 with no pTokens in contract", async function(){
        let balance = await arToken.balanceOf( gov.getAddress() );
        expect(balance).to.be.equal("994987500000000000000");
      });

      it("estimate cost", async function(){
        await arShield.connect(gov).changeCapped(true);
        await covBase.connect(gov).changeAllowed(true);
        let firstBal = await user.getBalance();
        let pendingMint = await arShield.connect(user).mint(ETHER.mul(1000), ZERO_ADDY);
        let lastBal = await user.getBalance();
      });
      
      it("should mint correctly with pTokens in contract", async function(){
        await arShield.connect(user).mint(ETHER.mul(1000), ZERO_ADDY);
        let userAr = await arToken.balanceOf( user.getAddress() );
        expect(userAr).to.be.equal("994987500000000000000");

        let shieldBal = await pToken.balanceOf( arShield.address );
        expect(shieldBal).to.be.equal( ETHER.mul(2000) );
      });

  });

  describe("#redeem", function () {

    beforeEach(async function() {
      await pToken.approve( arShield.address, ETHER.mul(100000) );
      await pToken.connect(user).approve( arShield.address, ETHER.mul(100000) );
      await arShield.connect(gov).mint(ETHER.mul(1000), ZERO_ADDY);
      await arToken.approve( arShield.address, ETHER.mul(100000) );
    });

    it("should redeem last pTokens in contract", async function(){
      let balance = await pToken.balanceOf( gov.getAddress() );
      let arBal = await arToken.balanceOf( gov.getAddress() );

      await arShield.redeem(arBal, ZERO_ADDY);

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
      await arShield.connect(user).redeem(arBal, ZERO_ADDY);

      let endBal = await pToken.balanceOf( user.getAddress() );
      let arBalance = await arToken.balanceOf( user.getAddress() );
      expect(arBalance).to.be.equal(0);

      let diff = endBal.sub(balance);
      expect(diff).to.be.equal("990000125156250000000");

      let pBal = await pToken.balanceOf(arShield.address);
    });

  });

  describe("#liquidate", function () {

    beforeEach(async function() {
      await pToken.approve( arShield.address, ETHER.mul(100000) );
      await arShield.mint(ETHER.mul(1000), ZERO_ADDY);
      await oracle.changeEthOwed(ETHER);
    });

    it("should return correct amounts on liqAmts", async function() {
      let ethOwed = ETHER;
      // 1000 tokens deposited, 25 tokens owed
      let tokensOwed = ETHER.mul(25).div(10);
      // Add the liquidator bonus.
      tokensOwed = tokensOwed.add(tokensOwed.div(200));
      let tokenFees = ETHER.mul(25).div(10);

      let liqAmt = await arShield.liqAmts(0);
      // 1 Ether, 2.5 tokens (0.25%) liq fees, 2.5 + 0.5% total tokens owed
      expect(liqAmt[0]).to.be.equal(ethOwed);
      expect(liqAmt[1]).to.be.equal(tokensOwed);
      expect(liqAmt[2]).to.be.equal(tokenFees);
    });

    it("should liquidate full liqAmts with 0 tokens owed, send to covBase, adjust liqAmts", async function() {
      await arShield.liquidate(0, {value: ETHER});

      let bal = await pToken.balanceOf( gov.getAddress() );
      expect(bal).to.be.equal("899002512500000000000000");
      let shieldBal = await gov.provider.getBalance(arShield.address);
      expect(shieldBal).to.be.equal("0")
      let covBal = await gov.provider.getBalance(covBase.address);
      expect(covBal).to.be.equal("1000000000000000000")

      let liqAmt = await arShield.feesToLiq(0);
      expect(liqAmt).to.be.equal(0);
    });

    it("should liquidate half of liqAmts with 0 tokens owed", async function() {
      await arShield.liquidate(0, {value: ETHER.div(2)});
      let bal = await pToken.balanceOf( gov.getAddress() );
      expect(bal).to.be.equal("899001256250000000000000");
    });      

    it("should liquidate with protocol fees", async function() {
      await covBase.changeEthOwed(ETHER.div(10));
      // 10 tokens given the value of 0.1 ETHER
      await oracle.changeTokensOwed(ETHER.mul(10));

      let liqAmt = await arShield.liqAmts(0);
      await arShield.liquidate(0, {value: liqAmt[0].toString()})
    });

    it("should fail on too much Ether", async function() {
      await expect(arShield.liquidate(0, {value: ETHER.mul(2)})).to.be.revertedWith("Too much Ether paid.");
    });

  });

  describe("#hack", function () {

    beforeEach(async function() {
      await pToken.approve( arShield.address, ETHER.mul(100000) );
      await arShield.mint(ETHER.mul(1000), ZERO_ADDY);
    });
    
      it("should pause upon correct deposit and set correct variables", async function() {
        await arShield.connect(user).notifyHack({value:ETHER.mul(10)});
        let locked = await arShield.locked();
        expect(locked).to.be.equal(true);
      });

      it("should not pause upon wrong deposit", async function() {
        await expect(arShield.connect(user).notifyHack({value:ETHER.mul(0)})).to.have.revertedWith("You must pay the deposit amount to notify a hack.");
      });

      it("should set correct variables upon confirmation", async function() {
        await arShield.notifyHack({value:ETHER.mul(10)});
        await arShield.connect(gov).confirmHack(69,420);
        expect(await arShield.payoutBlock()).to.be.equal(69);
        expect(await arShield.payoutAmt()).to.be.equal(420);
      });

      it("should be able to ban payouts from users", async function() {
        // Notify of hack, load contract with Ether.
        await arShield.notifyHack({value:ETHER.mul(10)});
        await gov.sendTransaction({to:arShield.address, value:ETHER});
        let arBalance = await arToken.balanceOf( gov.getAddress() )

        let block = await gov.provider.getBlockNumber();
        await mine();
        // Banning full balance of the user
        await arShield.banPayouts(block, [gov.getAddress()], [arBalance] )
        await arShield.connect(gov).confirmHack(block, arBalance);

        await expect(arShield.connect(gov).claim()).to.be.revertedWith("Sender did not have funds on payout block.");
      });

      it("should be able to claim funds", async function() {
        // Notify of hack, load contract with Ether.
        await arShield.notifyHack({value:ETHER.mul(10)});
        await gov.sendTransaction({'to':arShield.address, 'value':ETHER});

        let block = await gov.provider.getBlockNumber();
        await mine();
        // 0.001 ether per token
        await arShield.connect(gov).confirmHack(block,1000000000000000);
        
        await arShield.connect(gov).claim();
      });
  
      it("should be able to unlock contract", async function() {
        await arShield.connect(user).notifyHack({value:ETHER.mul(10)});
        await arShield.connect(gov).unlock();
        expect(await arShield.locked()).to.be.equal(false);
      });

      it("should not be able to unlock if not gov", async function() {
        await expect(arShield.connect(user).unlock()).to.be.revertedWith("You may not do this while the contract is unlocked.");
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

    it("should be able to withdraw", async function() {
      let bal = await pToken.balanceOf( gov.getAddress() );
      await arShield.withdraw( gov.getAddress() );
      let endBal = await pToken.balanceOf( gov.getAddress() );
      expect(endBal).to.be.equal( bal.add("2500000000000000000") )
    });

  });

  describe("#miscellaneous", function () {

    beforeEach(async function() {
      await pToken.approve( arShield.address, ETHER.mul(100000) );
      await arShield.mint(ETHER.mul(1000), ZERO_ADDY);
    });

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

});
