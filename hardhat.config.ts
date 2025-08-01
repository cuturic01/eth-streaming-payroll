import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "./tasks/EthStreamer";

const config: HardhatUserConfig = {
  solidity:{
    version:"0.8.30",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000
      },
    },
  }, 
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
  },
};

export default config;
