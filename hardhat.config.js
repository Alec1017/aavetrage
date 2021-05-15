/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require('dotenv').config();
 require("@nomiclabs/hardhat-ethers");
 
 const { ALCHEMY_MAINNET_URL, ALCHEMY_KOVAN_URL, METAMASK_PRIVATE_KEY } = process.env;
 
 module.exports = {
    solidity: "0.6.12",
    defaultNetwork: "localhost",
    networks: {
       hardhat: {
         forking: {
            url: ALCHEMY_MAINNET_URL
         }
       },
       kovan: {
          url: ALCHEMY_KOVAN_URL,
          accounts: [`0x${METAMASK_PRIVATE_KEY}`]
       }
    },
 }
