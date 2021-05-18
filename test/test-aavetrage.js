const hre = require("hardhat");
const { expect } = require("chai");

const addresses = require('../utils/addresses')


describe("Aavetrage Tests", function () {
    let Aavetrage;
    let aavetrageContract;
    let owner;

    let daiToken;

    let zeroAddress = '0x0000000000000000000000000000000000000000'

    before(async function () {
        let token = await hre.ethers.getContractAt('@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20', addresses.tokens.mainnet.DAI);

        let signers = await hre.ethers.getSigners();
        let signer = signers[0];

        daiToken = token.connect(signer);
    });

    beforeEach(async function () {
        Aavetrage = await hre.ethers.getContractFactory("Aavetrage");

        let signers = await hre.ethers.getSigners();
        owner = signers[0];

        aavetrageContract = await Aavetrage.deploy(addresses.aave.mainnetProvider, addresses.uniswap.mainnetFactory, addresses.tokens.mainnet.WETH);
    });

 
    describe("Deployment", function () {
        it("Should ensure there is DAI than can be used as capital", async function () {
            const ownerBalance = await daiToken.balanceOf(owner.address);
            expect(parseInt(ownerBalance)).to.be.greaterThan(0);
        });
    });

    describe("Peek", function() {
        it("Should revert not have a borrow or supply token set before Peek", async function() {
            const borrowToken = await aavetrageContract.borrowToken()
            const supplyToken = await aavetrageContract.supplyToken()

            expect(borrowToken).to.equal(zeroAddress);
            expect(supplyToken).to.equal(zeroAddress);
        });

        it("Should set a best borrow and best supply token after Peek", async function() {
            const peek = await aavetrageContract.peek()
            const peekResult = await peek.wait()
            
            const borrowToken = await aavetrageContract.borrowToken()
            const supplyToken = await aavetrageContract.supplyToken()

            expect(borrowToken).to.not.equal(zeroAddress);
            expect(supplyToken).to.not.equal(zeroAddress);
        });
    })

//   describe("Transactions", function () {
//     it("Should transfer tokens between accounts", async function () {
//       // Transfer 50 tokens from owner to addr1
//       await hardhatToken.transfer(addr1.address, 50);
//       const addr1Balance = await hardhatToken.balanceOf(addr1.address);
//       expect(addr1Balance).to.equal(50);

//       // Transfer 50 tokens from addr1 to addr2
//       // We use .connect(signer) to send a transaction from another account
//       await hardhatToken.connect(addr1).transfer(addr2.address, 50);
//       const addr2Balance = await hardhatToken.balanceOf(addr2.address);
//       expect(addr2Balance).to.equal(50);
//     });

//     it("Should fail if sender doesn’t have enough tokens", async function () {
//       const initialOwnerBalance = await hardhatToken.balanceOf(owner.address);

//       // Try to send 1 token from addr1 (0 tokens) to owner (1000 tokens).
//       // `require` will evaluate false and revert the transaction.
//       await expect(
//         hardhatToken.connect(addr1).transfer(owner.address, 1)
//       ).to.be.revertedWith("Not enough tokens");

//       // Owner balance shouldn't have changed.
//       expect(await hardhatToken.balanceOf(owner.address)).to.equal(
//         initialOwnerBalance
//       );
//     });

//     it("Should update balances after transfers", async function () {
//       const initialOwnerBalance = await hardhatToken.balanceOf(owner.address);

//       // Transfer 100 tokens from owner to addr1.
//       await hardhatToken.transfer(addr1.address, 100);

//       // Transfer another 50 tokens from owner to addr2.
//       await hardhatToken.transfer(addr2.address, 50);

//       // Check balances.
//       const finalOwnerBalance = await hardhatToken.balanceOf(owner.address);
//       expect(finalOwnerBalance).to.equal(initialOwnerBalance - 150);

//       const addr1Balance = await hardhatToken.balanceOf(addr1.address);
//       expect(addr1Balance).to.equal(100);

//       const addr2Balance = await hardhatToken.balanceOf(addr2.address);
//       expect(addr2Balance).to.equal(50);
//     });
//   });
});