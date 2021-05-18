const hre = require("hardhat");

require('dotenv').config();

const contractArtifact = require('../artifacts/contracts/Aavetrage.sol/Aavetrage.json');
const erc20ABI = require('../utils/standardABI')
const addresses = require('../utils/addresses');

async function run(collateralAmount) {

    // Get the provider
    const provider = new hre.ethers.providers.AlchemyProvider('kovan', process.env.ALCHEMY_API_KEY)

    // Get the metamask wallet addresss
    const wallet = new hre.ethers.Wallet(process.env.METAMASK_PRIVATE_KEY, provider)

    // Create contract instances
    const aavetrage = new hre.ethers.Contract(contractArtifact.deployAddress, contractArtifact.abi, wallet)
    const kovanDAI = new hre.ethers.Contract(addresses.tokens.kovan.DAI, erc20ABI, wallet);

    // call peek()
    const peek = await aavetrage.peek()
    const peekResult = await peek.wait()

    console.log('Determined best borrow and supply tokens');

    // // uses kovan DAI as collateral
    const collateral = hre.ethers.utils.parseEther(collateralAmount.toString())

    // approve the transfer of 100 kovan DAI to aavetrage
    const approval = await kovanDAI.approve(aavetrage.address, collateral, { gasLimit: 100000 });
    const approvalResult = await approval.wait()

    console.log('Supplied collateral')

    // call guap()
    const guap = await aavetrage.guap(addresses.tokens.kovan.DAI, collateral, {gasLimit: 1200000});
    const guapResult = await guap.wait();

    console.log('Supplied tokens to Aave');

    // unwind the position
    const shut = await aavetrage.shut({gasLimit: 1200000});
    const shutResult = await shut.wait()

    console.log('Unwound position and withdrew collateral');
}


// Run the script with 100 DAI posted as collateral
run(100)
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });