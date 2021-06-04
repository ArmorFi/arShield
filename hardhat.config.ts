import "@nomiclabs/hardhat-waffle";
import "solidity-coverage";
import "hardhat-spdx-license-identifier";
import "hardhat-log-remover";
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

export default {
  spdxLicenseIdentifier: {
    overwrite: true,
    runOnCompile: true,
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
    hardhat: {
      gas: 10000000,
      accounts: {
        accountsBalance: "1000000000000000000000000"
      },
      allowUnlimitedContractSize: true,
      timeout: 1000000
    },
    coverage: {
      url: 'http://localhost:8555'
    }
  }
};

