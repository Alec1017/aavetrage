const fs = require('fs');
const hre = require("hardhat");

const contractArtifact = require("../artifacts/contracts/Aavetrage.sol/Aavetrage.json");
const addresses = require('../utils/addresses');

async function deploy() {
    const Aavetrage = await hre.ethers.getContractFactory("Aavetrage");

    const aavetrage = await Aavetrage.deploy(addresses.aave.kovanProvider, addresses.uniswap.kovanFactory, addresses.tokens.kovan.WETH);

    await aavetrage.deployed();

    console.log("Aavetrage deployed to:", aavetrage.address);

    contractArtifact['deployAddress'] = aavetrage.address;

    await fs.promises.writeFile("./artifacts/contracts/Aavetrage.sol/Aavetrage.json", JSON.stringify(contractArtifact, null, 4), function(err, result) {
        if (err) console.log('error', err);
    })
}

deploy()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });