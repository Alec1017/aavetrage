const hre = require("hardhat");

async function deploy() {
    const Aavetrage = await hre.ethers.getContractFactory("Aavetrage");
    const aavetrage = await Aavetrage.deploy('0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5');

    await aavetrage.deployed();

    console.log("Aavetrage deployed to:", aavetrage.address);
}

deploy()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });