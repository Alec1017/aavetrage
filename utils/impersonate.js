const hre = require('hardhat');

const impersonateAddress = async (address) => {
  await hre.network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [address],
  });

  const signer = await hre.ethers.provider.getSigner(address);
  signer.address = signer._address;

  return signer;
};

module.exports = { 
    impersonateAddress
};