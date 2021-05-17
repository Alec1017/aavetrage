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

    const peek = await aavetrage.peek()
    const peekResult = await peek.wait()

    // // uses 100 kovan DAI as collateral
    const collateral = hre.ethers.utils.parseEther('100')

    const approval = await kovanDAI.approve(aavetrage.address, collateral, { gasLimit: 100000 });
    const approvalResult = await approval.wait()


    await aavetrage.guap(kovanDaiAddress, collateral, {gasLimit: 1200000});
    console.log(`${collateral} DAI collateral successfully deposited to Aave`);
}

async function borrow() {
    // Get the provider
    const provider = new hre.ethers.providers.AlchemyProvider('kovan', process.env.ALCHEMY_API_KEY) //kovan

    const wallet = new hre.ethers.Wallet(process.env.METAMASK_PRIVATE_KEY, provider)

    // Create a contract instance
    const aavetrage = new hre.ethers.Contract(contractArtifact.deployAddress, contractArtifact.abi, wallet)

    const [ bestBorrowToken, bestSupplyToken, rate ] = await aavetrage.peek()

    const values = await aavetrage.borrowToken(bestBorrowToken, {gasLimit: 400000});
    // console.log('Token was borrowed using collateral');
    // console.log(values);
}

// borrow()
//     .then(() => process.exit(0))
//     .catch(error => {
//         console.error(error);
//         process.exit(1);
//     });

run()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });