import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";


const config: HardhatUserConfig = {
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
};

export default config;
