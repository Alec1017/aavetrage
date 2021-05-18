const hre = require('hardhat');
const { expect, use } = require('chai');
const { solidity } = require('ethereum-waffle');

const addresses = require('../utils/addresses')
const { transferDai } = require('../utils/impersonate');

use(solidity);


describe('Aavetrage Tests', function () {
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

        // transfer enough DAI to the user account for the tests to work
        await transferDai(1000, signer.address);
    });

    beforeEach(async function () {
        Aavetrage = await hre.ethers.getContractFactory('Aavetrage');

        let signers = await hre.ethers.getSigners();
        owner = signers[0];

        aavetrageContract = await Aavetrage.deploy(addresses.aave.mainnetProvider, addresses.uniswap.router, addresses.tokens.mainnet.WETH);
    });

 
    describe("Deployment", function () {

        it("Should provide a contract address after deployment", async function() {
            expect(aavetrageContract.address).does.not.equal(zeroAddress);
        });

        it("Should ensure there is DAI than can be used as capital", async function() {
            const ownerBalance = await daiToken.balanceOf(owner.address);
            expect(parseInt(ownerBalance)).to.be.greaterThan(0);
        });
    });

    describe("Peek", function() {

        it("Should not have a borrow or supply token set before Peek", async function() {
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

    describe('Guap', function() {

        it('Should revert if there are no borrow or supply tokens set by Peek()', async function() {
            const collateral = hre.ethers.utils.parseEther('100')

            const approval = await daiToken.approve(aavetrageContract.address, collateral);
            const approvalResult = await approval.wait()

            await expect(aavetrageContract.guap(daiToken.address, collateral)).to.be.revertedWith('No borrow token found. Peek() not called yet.')
        });

        it('Should revert if no collateral is supplied to guap()', async function() {
            const peek = await aavetrageContract.peek()
            const peekResult = await peek.wait()

            await expect(aavetrageContract.guap(daiToken.address, hre.ethers.utils.parseEther('0'))).to.be.revertedWith('Must supply a collateral amount greater than 0.')
        });

        it('Should call guap() and debit collateral from end user account', async function() {
            const peek = await aavetrageContract.peek()
            const peekResult = await peek.wait()

            const collateral = hre.ethers.utils.parseEther('100')
            const initialDaiAmount = await daiToken.balanceOf(owner.address);

            const approval = await daiToken.approve(aavetrageContract.address, collateral);
            const approvalResult = await approval.wait()

            const guap = await aavetrageContract.guap(daiToken.address, collateral);
            const guapResult = await guap.wait();

            const resultDaiAmount = await daiToken.balanceOf(owner.address);

            expect(initialDaiAmount).gt(resultDaiAmount)
        })
    });

    describe('Shut', async function() {

        it('Should revert if there are no borrow or supply tokens set by Peek()', async function() {
            await expect(aavetrageContract.shut()).to.be.revertedWith('No borrow token found. Peek() not called yet.')
        });

        it('Should successfully unwind an arbitrage position', async function() {
            const peek = await aavetrageContract.peek()
            const peekResult = await peek.wait()

            const collateral = hre.ethers.utils.parseEther('100')

            const approval = await daiToken.approve(aavetrageContract.address, collateral);
            const approvalResult = await approval.wait()

            const guap = await aavetrageContract.guap(daiToken.address, collateral);
            const guapResult = await guap.wait();

            const initialDaiAmount = await daiToken.balanceOf(owner.address);

            const shut = await aavetrageContract.shut();
            const shutResult = await shut.wait()

            const resultDaiAmount = await daiToken.balanceOf(owner.address);

            expect(initialDaiAmount).lt(resultDaiAmount)
        })
    })
});