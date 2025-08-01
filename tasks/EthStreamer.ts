import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task(
  "deploy-eth-streamer",
  "Deploys the EthStreamer contract"
).setAction(async (_args, hre: HardhatRuntimeEnvironment) => {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with:", deployer.address);

  const EthStreamerFactory = await hre.ethers.getContractFactory(
    "EthStreamer"
  );
  const streamer = await EthStreamerFactory.deploy();
  await streamer.waitForDeployment();
  const streamerAddress = await streamer.getAddress();
  console.log("EthStreamer deployed at:", streamerAddress);
});
