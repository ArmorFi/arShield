import "@nomiclabs/hardhat-waffle";
import "solidity-coverage";
import "hardhat-spdx-license-identifier";
import "hardhat-log-remover";
//import "hardhat-gas-reporter";
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more


let hardhatSettings:any = {
      gas: 10000000,
      accounts: {
        accountsBalance: "1000000000000000000000000"
      },
      allowUnlimitedContractSize: true,
      timeout: 1000000
    };

if (process.env.MAINNET_FORK) {
  hardhatSettings = {
      gas: 10000000,
      chainId: 1,
      accounts: {
        accountsBalance: "1000000000000000000000000"
      },
    forking: { url: "https://eth-mainnet.alchemyapi.io/v2/90dtUWHmLmwbYpvIeC53UpAICALKyoIu", blockNumber: 12633224 },
      allowUnlimitedContractSize: true,
      timeout: 6000000
    };
}
export default {
  spdxLicenseIdentifier: {
    overwrite: true,
    runOnCompile: true,
  },
  gasReporter: {
    enabled: false,
    currency: 'USD',
    gasPrice: 100,
  },
  solidity: {
    compilers :[
      {
        version: "0.6.6",
      },
      {
        version:"0.5.16",
        settings:{
          optimizer: {
            enabled: true,
            runs: 999999
          }
        }
      },
      {
        version: "0.6.12",
        settings: {
          optimizer : {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.8.4",
        settings: {
          optimizer : {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },
  networks: {
    hardhat: hardhatSettings,
    coverage: {
      url: 'http://localhost:8555'
    }
  }
};

