import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import { increase, getTimestamp, mine } from "./utils";
import { Address } from "ethereumjs-util";
import { hasUncaughtExceptionCaptureCallback } from "process";
const ETHER = BigNumber.from("1000000000000000000");
const ZERO_ADDY = "0x0000000000000000000000000000000000000000";

async function main() {
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

}