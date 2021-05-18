const hre = require("hardhat");

const addresses = require('../utils/addresses');
const { impersonateAddress } = require('../utils/impersonate');

const amount = hre.ethers.utils.parseEther('10000');
const receiver = addresses.users.hardhat;

async function transfer() {
  console.log(`Transferring ${hre.ethers.utils.formatEther(amount)} DAI from a holder to ${receiver}...`);

  const holder = await impersonateAddress(addresses.holders.DAI);

  let token = await hre.ethers.getContractAt('@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20', addresses.tokens.mainnet.DAI);

  token = token.connect(holder);

  await token.transfer(receiver, amount);

  let balance = await token.balanceOf(receiver);
  console.log(`receiver balance after: ${hre.ethers.utils.formatEther(balance)}`);
}

transfer()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });