import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { Contract, Signer, BigNumber, constants } from "ethers";
import { increase, getTimestamp } from "./utils";
import { Address } from "ethereumjs-util";

const {
  LeafKeyCoder,
  LeafValueCoder,
  SortedMerkleTree,
  APIClient,
  ChainContract,
  ContractRegistry,
  ABI
} = require('@umb-network/toolbox');

const ETHER = BigNumber.from("1000000000000000000");
if(process.env.ROPSTEN_FORK) {
  describe.only("umbrella oracle_onchain", function () {
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
    let apiClient: typeof APIClient;
    let lastBlockId: number;

    let umbrellaRegistryAddress = '0x968A798Be3F73228c66De06f7D1109D8790FB64D';
    let ETH_USD_KEY = LeafKeyCoder.encode("ETH-USD")

    let umbrellaChainContract: Contract;
    // let yTokenList = [
    //   "0xE14d13d8B3b85aF791b2AADD661cDBd5E6097Db1", // yvYFI
    //   "0xB8C3B7A2A618C552C23B1E4701109a9E756Bab67", // yv1Inch
    //   "0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9", // yvUSDC
    // ];

    // USE other token list since, there yTokens not listed to umbrella yet
    let yTokenKeys = [
      "ZRX-USD",
    ];

    beforeEach(async function() {
      accounts = await ethers.getSigners();
      gov = accounts[0];
      user = accounts[1];

      let umbrellaRegistry = new ContractRegistry(hre.ethers.provider, umbrellaRegistryAddress)
      umbrellaChainContract = new Contract(await umbrellaRegistry.getAddress('Chain'), ABI.chainAbi, hre.ethers.provider)

      const ORACLE = await ethers.getContractFactory("UmbrellaOracle");
      oracle = await ORACLE.deploy(umbrellaRegistryAddress, ETH_USD_KEY);

      apiClient = new APIClient({
        baseURL: 'https://api.umb.network',
        umbrellaChainContract,
        apiKey: '9ee5e662a5f425dc103a6c04a91e4973bcca93ea74c8f2be8e08124067b33c7b',
      });

      lastBlockId = Number((await umbrellaChainContract.getLatestBlockId()).toString())
    });

    describe("#getEthPrice", function () {
      it('check', async function() {
        const ethPrice = (await umbrellaChainContract.getCurrentValue(ETH_USD_KEY)).value;
        expect(await oracle.getEthPrice()).to.be.equal(ethPrice)
      })
    });

    describe("#getTokensOwed", function () {
      for (let i = 0; i < yTokenKeys.length; i += 1) {
        it("check", async function() {
          const proofData = await apiClient.getProofs([yTokenKeys[i]])
          console.log(lastBlockId)
          console.log(proofData)
          const res = await oracle.getTokensOwed(
            ETHER,
            LeafKeyCoder.encode(yTokenKeys[i]),
            proofData.leaves[0].proof,
            proofData.leaves[0].value
          );
        });
      }
    });
    // describe("#getEthOwed", function () {
    //   for(let i = 0; i<yTokenList.length; i++){
    //     it("check", async function(){
    //       const res = await oracle.getEthOwed(ETHER, yTokenList[i], link[i]);
    //       console.log(res.toString());
    //       console.log(ETHER.toString());
    //     });
    //   }
    // });
  });
}
