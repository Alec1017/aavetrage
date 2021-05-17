const hre = require("hardhat");

require('dotenv').config();

const contractArtifact = require('../artifacts/contracts/Aavetrage.sol/Aavetrage.json');
const erc20ABI = require('../utils/standardABI')
const kovanDaiAddress = '0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD'

async function run() {

    // Get the provider
    const provider = new hre.ethers.providers.AlchemyProvider('kovan', process.env.ALCHEMY_API_KEY) //kovan
    // const provider = new hre.ethers.providers.JsonRpcProvider('http://localhost:8545') //mainnet

    const wallet = new hre.ethers.Wallet(process.env.METAMASK_PRIVATE_KEY, provider)

    // Create a contract instance
    const aavetrage = new hre.ethers.Contract(contractArtifact.deployAddress, contractArtifact.abi, wallet)
    const kovanDAI = new hre.ethers.Contract(kovanDaiAddress, erc20ABI, wallet);

    const [ bestBorrowToken, bestSupplyToken ] = await aavetrage.peek()

    console.log('best borrow', bestBorrowToken);
    console.log('best supply', bestSupplyToken);

    // // uses 100 kovan DAI as collateral
    const collateral = hre.ethers.utils.parseEther('100')

    const approval = await kovanDAI.approve(aavetrage.address, collateral, { gasLimit: 100000 });
    const approvalResult = await approval.wait()


    await aavetrage.guap(bestBorrowToken, bestSupplyToken, kovanDaiAddress, collateral, {gasLimit: 400000});
    console.log(`${collateral} DAI collateral successfully deposited to Aave`);
}

run()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });