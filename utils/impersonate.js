const hre = require('hardhat');
const addresses = require('./addresses')

async function impersonateAddress(address) {
  await hre.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [address],
  });

  const signer = await hre.ethers.provider.getSigner(address);
  signer.address = signer._address;

  return signer;
};

async function transferDai(value, receiver) {
  const amount = hre.ethers.utils.parseEther(String(value))

  console.log(`Transferring ${hre.ethers.utils.formatEther(amount)} DAI from a holder to ${receiver}...`);

  const holder = await impersonateAddress(addresses.holders.DAI);

  let token = await hre.ethers.getContractAt('@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20', addresses.tokens.mainnet.DAI);

  token = token.connect(holder);

  await token.transfer(receiver, amount);

  let balance = await token.balanceOf(receiver);
  console.log(`receiver balance after: ${hre.ethers.utils.formatEther(balance)}`);
}

module.exports = { 
    transferDai
};