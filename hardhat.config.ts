import { HardhatUserConfig } from "hardhat/config";
import '@typechain/hardhat'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'


const config: HardhatUserConfig = {
  solidity: {
    compilers: [{ version: "0.8.2", settings: {
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
};

export default config;

