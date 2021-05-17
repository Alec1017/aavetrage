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

    constructor(address _provider) public {
        provider = ILendingPoolAddressesProvider(_provider);
        lendingPool = ILendingPool(provider.getLendingPool());
        priceOracle = IPriceOracle(provider.getPriceOracle());

        uniswapRouter = IUniswapV2Router02(UNISWAP_FACTORY);
    }

    event Peek(address bestBorrow, address bestSupply, uint256 lowestBorrowRate, uint256 highestSupplyRate);
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

        // Deposit the collateral into Aave
        depositToken(address(collateralToken), collateralAmount);

        // borrow the token with the lowest borrow rate
        borrowAaveToken(address(borrowToken));

        // swap the borrowed to token for the best supply token
        swapTokens(address(borrowToken), address(supplyToken), borrowToken.balanceOf(address(this)), 1, address(this));

        // deposit the swapped supply token
        depositToken(address(supplyToken), supplyToken.balanceOf(address(this)));
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
        uint256 amountToBorrow = uint256((availBorrow).div(tokenPrice)) * (10 ** tokenDecimals);

        return amountToBorrow;
    }


    // function withdrawToken(address token) private {

    //     // Withdraws the entire available 
    //     lendingPool.withdraw(token, type(uint).max, msg.sender);
    // }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin, address to) private {
        IERC20(tokenIn).approve(address(uniswapRouter), amountIn);

        // build path for swapping tokens
        address[] memory path = new address[](3);
        path[0] = tokenIn;
        path[1] = WETH;
        path[2] = tokenOut;

        uniswapRouter.swapExactTokensForTokens(amountIn, amountOutMin, path, to, block.timestamp);

        emit Swap(tokenIn, tokenOut, amountIn, amountOutMin, to);
    }
}