/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require('dotenv').config();
 require("@nomiclabs/hardhat-ethers");
 
 const { ALCHEMY_API_URL, METAMASK_PRIVATE_KEY } = process.env;
 
 module.exports = {
    solidity: "0.7.3",
    defaultNetwork: "localhost",
    networks: {
       hardhat: {},
       kovan: {
          url: ALCHEMY_API_URL,
          accounts: [`0x${METAMASK_PRIVATE_KEY}`]
       }
    },
 }
