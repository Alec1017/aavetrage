const hre = require("hardhat");

require('dotenv').config();

const { ALCHEMY_API_KEY } = process.env;
const contractArtifact = require('../artifacts/contracts/Aavetrage.sol/Aavetrage.json')

async function run() {

    // Get the provider
    // const provider = new hre.ethers.providers.AlchemyProvider('kovan', ALCHEMY_API_KEY) //kovan
    const provider = new hre.ethers.providers.JsonRpcProvider('http://localhost:8545') //mainnet

    // Create a contract instance
    const aavetrage = new hre.ethers.Contract(contractArtifact.deployAddress, contractArtifact.abi, provider)

    const result = await aavetrage.functions.peek()

    console.log(result)
}

run()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });