const fs = require('fs');
const hre = require("hardhat");

const contractArtifact = require("../artifacts/contracts/Aavetrage.sol/Aavetrage.json");

async function deploy() {
    const Aavetrage = await hre.ethers.getContractFactory("Aavetrage");

    // kovan: 0x88757f2f99175387aB4C6a4b3067c77A695b0349
    // mainnet: 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5
    const aavetrage = await Aavetrage.deploy('0x88757f2f99175387aB4C6a4b3067c77A695b0349');

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