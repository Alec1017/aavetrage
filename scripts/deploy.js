const hre = require("hardhat");

async function deploy() {
    const Aavetrage = await hre.ethers.getContractFactory("Aavetrage");
    const aavetrage = await Aavetrage.deploy('0x88757f2f99175387ab4c6a4b3067c77a695b0349');

    await aavetrage.deployed();

    console.log("Aavetrage deployed to:", aavetrage.address);
}

deploy()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });