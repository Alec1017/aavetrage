const hre = require("hardhat");

async function deploy() {
    const Greeter = await hre.ethers.getContractFactory("Test");
    const greeter = await Greeter.deploy();

    await greeter.deployed();

    console.log("Greeter deployed to:", greeter.address);
}

deploy()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });