import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";

// import { Secrets } from "./test/common/Secrets";
// let accounts: string[] = [];
// Secrets.fromAws().then(s => { accounts.push(s.PRIVATEKEY_TEST_MINER); }).catch(console.error).then(() => {console.log('Accounts:', accounts);});

const config = {
    solidity: {
      compilers: [{ version: "0.8.24", settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      } }],
    },
    networks: {
      local: {
        chainId: 31337,
        url: 'http://localhost:8545',
      }
    }
  } as HardhatUserConfig;

export default config;
