// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import { ReserveConfiguration } from '@aave/protocol-v2/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import { ILendingPoolAddressesProvider } from '@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol';
import { ILendingPool } from '@aave/protocol-v2/contracts/interfaces/ILendingPool.sol';
import { IPriceOracle } from '@aave/protocol-v2/contracts/interfaces/IPriceOracle.sol';
import { DataTypes } from '@aave/protocol-v2/contracts/protocol/libraries/types/DataTypes.sol';
import { ICreditDelegationToken } from '@aave/protocol-v2/contracts/interfaces/ICreditDelegationToken.sol';

import { IUniswapV2Router02 } from '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';


contract Aavetrage {
    using SafeMath for uint256;

    // Used to determine the number of decimals for a reserve
    uint256 constant DECIMALS_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF;
    uint256 constant RESERVE_DECIMALS_START_BIT_POSITION = 48;

    // uniswap Kovan contract addresses
    address constant UNISWAP_FACTORY = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address constant WETH = address(0xd0A1E359811322d97991E03f863a0C30C2cF029C);

    ILendingPoolAddressesProvider private provider;
    ILendingPool private lendingPool;
    IPriceOracle private priceOracle;

    IUniswapV2Router02 private uniswapRouter;

    IERC20 private borrowToken;
    IERC20 private supplyToken;
    IERC20 private collateralToken;

    uint256 private collateralReserve;

    constructor(address _provider) public {
        provider = ILendingPoolAddressesProvider(_provider);
        lendingPool = ILendingPool(provider.getLendingPool());
        priceOracle = IPriceOracle(provider.getPriceOracle());

        uniswapRouter = IUniswapV2Router02(UNISWAP_FACTORY);
    }

    event Peek(address bestBorrow, address bestSupply, uint256 lowestBorrowRate, uint256 highestSupplyRate);
    event Guap(address collateralToken, address borrowToken, address supplyToken);
    event Borrow(address tokenBorrowed, uint256 amountBorrowed);
    event Swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin, address to);


    function peek() public {

        // Get all reserves on Aave
        address[] memory reserves = lendingPool.getReservesList();

        uint128 highestSupplyRate = 0; 
        uint128 lowestBorrowRate = type(uint128).max;

        address bestSupplyToken;
        address bestBorrowToken;

        for (uint256 i = 0; i < reserves.length; i++) {
            DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(reserves[i]);

            // Store the reserve with the highest supply rate
            if (reserveData.currentLiquidityRate > highestSupplyRate) {
                bestSupplyToken = reserves[i];
                highestSupplyRate = reserveData.currentLiquidityRate;
            }

            // Store the reserve with the lowest, non-zero borrow rate
            if (reserveData.currentVariableBorrowRate > 0 && reserveData.currentVariableBorrowRate < lowestBorrowRate) {
                bestBorrowToken = reserves[i];
                lowestBorrowRate = reserveData.currentVariableBorrowRate;
            }
        }

        require(bestBorrowToken != address(0), 'No best borrow token found');
        require(bestSupplyToken != address(0), 'No best supply token found');
        require(highestSupplyRate > lowestBorrowRate, 'Supply rate should strictly be greater than borrow rate');

        borrowToken = IERC20(bestBorrowToken);
        supplyToken = IERC20(bestSupplyToken);

        emit Peek(bestBorrowToken, bestSupplyToken, lowestBorrowRate, highestSupplyRate);
    }


    function guap(address collateralAsset, uint256 collateralAmount) public {
        require(address(borrowToken) != address(0), 'No borrow token found. Peek() not called yet.');
        require(address(supplyToken) != address(0), 'No supply token found. Peek() not called yet.');
        require(collateralAmount > 0, 'Must supply a collateral amount greater than 0.');

        // Transfer collateral token to this contract
        collateralToken = IERC20(collateralAsset);
        collateralToken.transferFrom(msg.sender, address(this), collateralAmount);

        // put 5% of collateral into a reserve for repaying interest later
        (uint256 remainingCollateral, uint256 reserve) = partitionFunds(collateralAmount, 5);
        collateralReserve = reserve;

        // Deposit the collateral into Aave
        depositToken(address(collateralToken), remainingCollateral);

        // borrow the token with the lowest borrow rate
        borrowAaveToken(address(borrowToken));

        // swap the borrowed to token for the best supply token
        swapTokens(address(borrowToken), address(supplyToken), borrowToken.balanceOf(address(this)), 1, address(this), false);

        // deposit the swapped supply token
        depositToken(address(supplyToken), supplyToken.balanceOf(address(this)));

        emit Guap(address(collateralToken), address(borrowToken), address(supplyToken));
    }


    function shut() public {
        require(address(borrowToken) != address(0), 'No borrow token found. Peek() not called yet.');
        require(address(supplyToken) != address(0), 'No supply token found. Peek() not called yet.');

        // withdraw the supply token
        lendingPool.withdraw(address(supplyToken), type(uint).max, address(this));

        // swap the supply token for the borrow token
        swapTokens(address(supplyToken), address(borrowToken), supplyToken.balanceOf(address(this)), 1, address(this), false);

        // swap collateral reserve to the borrow token to cover interest
        swapTokens(address(collateralToken), address(borrowToken), collateralToken.balanceOf(address(this)), 1, address(this), true);

        // repay the borrow token
        borrowToken.approve(address(lendingPool), borrowToken.balanceOf(address(this)));
        lendingPool.repay(address(borrowToken), borrowToken.balanceOf(address(this)), 2, address(this));

        // withdraw the collateral token
        lendingPool.withdraw(address(collateralToken), type(uint).max, address(this));

        // transfer collateral funds back to end-user
        collateralToken.transfer(msg.sender, collateralToken.balanceOf(address(this)));
    }


    function depositToken(address token, uint256 amount) private {
        // approve the deposit
        IERC20(token).approve(address(lendingPool), amount);

        // Deposit the asset
        lendingPool.deposit(token, amount, address(this), 0);
    }


    function borrowAaveToken(address token) private {
        DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(token);

        uint256 borrowAmount = determineBorrowAmount(token);

        // Delegate this contract as a borrower on behalf of msg.sender
        ICreditDelegationToken(reserveData.variableDebtTokenAddress).approveDelegation(address(this), borrowAmount);

        // borrow the token from Aave
        lendingPool.borrow(token, borrowAmount, 2, 0, address(this));

        emit Borrow(token, borrowAmount);
    }


    function determineBorrowAmount(address token) private view returns (uint256) {
        (, , uint256 availBorrow , , ,) = lendingPool.getUserAccountData(address(this));

        DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(token);

        uint256 tokenDecimals = (reserveData.configuration.data & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION;
        
        // Get the token price in ETH using a price oracle
        uint256 tokenPrice = priceOracle.getAssetPrice(token);

        // Divide the amount in ETH that is available to use as borrow collateral by the individual token price in ETH
        uint256 amountToBorrow = availBorrow.mul(10 ** tokenDecimals).div(tokenPrice);

        return amountToBorrow;
    }


    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin, address to, bool swapReserve) private {
        IERC20(tokenIn).approve(address(uniswapRouter), amountIn);

        // build path for swapping tokens
        address[] memory path;
        if (swapReserve) {
            // Stablecoin collaterals get better rates with a direct path
            path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;
        } else {
            // everything else should use WETH as an intermediary
            path = new address[](3);
            path[0] = tokenIn;
            path[1] = WETH;
            path[2] = tokenOut;
        }

        uniswapRouter.swapExactTokensForTokens(amountIn, amountOutMin, path, to, block.timestamp);

        emit Swap(tokenIn, tokenOut, amountIn, amountOutMin, to);
    }


    function partitionFunds(uint256 amount, uint256 percentage) private view returns (uint256, uint256) {
        uint256 reserve = amount.mul(percentage).div(100);

        uint remaining = amount.sub(reserve);

        return (remaining, reserve);
    }
}