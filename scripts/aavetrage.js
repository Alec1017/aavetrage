const hre = require("hardhat");

require('dotenv').config();

const contractArtifact = require('../artifacts/contracts/Aavetrage.sol/Aavetrage.json')

async function run() {

    // Get the provider
    // const provider = new hre.ethers.providers.AlchemyProvider('kovan', process.env.ALCHEMY_API_KEY) //kovan
    const provider = new hre.ethers.providers.JsonRpcProvider('http://localhost:8545') //mainnet

    // Create a contract instance
    const aavetrage = new hre.ethers.Contract(contractArtifact.deployAddress, contractArtifact.abi, provider)

    const [ bestBorrowToken, bestSupplyToken ] = await aavetrage.functions.peek()

    console.log('best borrow', bestBorrowToken);
    console.log('best supply', bestSupplyToken);
}

run()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });