import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import { increase, getTimestamp } from "./utils";
import { Address } from "ethereumjs-util";
const ETHER = BigNumber.from("1000000000000000000");
if(process.env.MAINNET_FORK) {
  describe.only("oracle_onchain", function () {
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

    let yTokenList = [
      "0xE14d13d8B3b85aF791b2AADD661cDBd5E6097Db1", // yvYFI
      "0xB8C3B7A2A618C552C23B1E4701109a9E756Bab67", // yv1Inch
      "0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9", // yvUSDC
    ];

    let link = [
      "0x7c5d4F8345e66f68099581Db340cd65B078C41f4", // YFI/ETH
      "0x72AFAECF99C9d9C8215fF44C77B94B99C28741e8", // 1inch/ETH
      "0x986b5E1e1755e3C2440e960477f25201B0a8bbD4", // usdc/ETH
    ];
    beforeEach(async function() {
      accounts = await ethers.getSigners();
      gov = accounts[0];
      user = accounts[1];
      const ORACLE = await ethers.getContractFactory("YearnOracle");
      oracle = await ORACLE.deploy();
    });
    describe("#uToY", function () {
      for(let i = 0; i<yTokenList.length; i++){
        it("check", async function(){
          const res = await oracle.uToY(yTokenList[i], ETHER);
          console.log(res.toString());
          console.log(ETHER.toString());
        });
      }
    });
    describe("#ethToU", function () {
      for(let i = 0; i<yTokenList.length; i++){
        it("check", async function(){
          const res = await oracle.ethToU(ETHER, link[i]);
          console.log(res.toString());
          console.log(ETHER.toString());
        });
      }
    });
    describe("#getTokensOwed", function () {
      for(let i = 0; i<yTokenList.length; i++){
        it("check", async function(){
          const res = await oracle.getTokensOwed(ETHER, yTokenList[i], link[i]);
          console.log(res.toString());
          console.log(ETHER.toString());
        });
      }
    });
    describe("#getEthOwed", function () {
      for(let i = 0; i<yTokenList.length; i++){
        it("check", async function(){
          const res = await oracle.getEthOwed(ETHER, yTokenList[i], link[i]);
          console.log(res.toString());
          console.log(ETHER.toString());
        });
      }
    });
  });
}
