/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require('dotenv').config();
require("@nomiclabs/hardhat-ethers");
 
const { ALCHEMY_API_KEY, METAMASK_PRIVATE_KEY } = process.env;
 
module.exports = {
   solidity: "0.6.12",
   defaultNetwork: "localhost",
   networks: {
      hardhat: {
         forking: {
            url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
            blockNumber: 12095000
         }
      },
      kovan: {
         url: `https://eth-kovan.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
         accounts: [`0x${METAMASK_PRIVATE_KEY}`]
      }
   },
   mocha: {
      timeout: 600000
   }
}
