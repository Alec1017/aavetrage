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


contract Aavetrage {
    using SafeMath for uint256;

    // Used to determine the number of decimals for a reserve
    uint256 constant DECIMALS_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF;
    uint256 constant RESERVE_DECIMALS_START_BIT_POSITION = 48;

    ILendingPoolAddressesProvider private provider;
    ILendingPool private lendingPool;
    IPriceOracle private priceOracle;

    constructor(address _provider) public {
        provider = ILendingPoolAddressesProvider(_provider);
        lendingPool = ILendingPool(provider.getLendingPool());
        priceOracle = IPriceOracle(provider.getPriceOracle());
    }

    event Borrow(address tokenBorrowed, uint256 amountBorrowed);


    function peek() public view returns (address, address) {

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

        return (bestBorrowToken, bestSupplyToken);
    }

    function guap(address bestBorrowToken, address bestSupplyToken, address collateralAsset, uint256 collateralAmount) public {
        // Transfer collateral token to this contract
        IERC20(collateralAsset).transferFrom(msg.sender, address(this), collateralAmount);

        // Deposit the collateral into Aave
        depositCollateral(collateralAsset, collateralAmount);

        // borrow the token with the lowest borrow rate
        // borrowToken(bestBorrowToken);
    }


    function depositCollateral(address token, uint256 collateralAmount) private {
        // approve the deposit
        IERC20(token).approve(address(lendingPool), collateralAmount);

        // Deposit the collateral asset (kovan DAI)
        lendingPool.deposit(token, collateralAmount, address(this), 0);
    }


    function borrowToken(address token) public {
        DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(token);

        uint256 borrowAmount = determineBorrowAmount(token);

        // Delegate this contract as a borrower on behalf of msg.sender
        ICreditDelegationToken(reserveData.variableDebtTokenAddress).approveDelegation(address(this), borrowAmount);

        // borrow the token from Aave
        lendingPool.borrow(token, borrowAmount, 2, 0, address(this));

        emit Borrow(token, borrowAmount);

    }

    function determineBorrowAmount(address token) private view returns (uint256) {
        DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(token);

        uint256 tokenDecimals = (reserveData.configuration.data & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION;
        
        // Get the token price in ETH using a price oracle
        uint256 tokenPrice = priceOracle.getAssetPrice(token);

        // Divide the amount in ETH that is available to use as borrow collateral by the individual token price in ETH
        uint256 amountToBorrow = uint256((availBorrow).div(tokenPrice)) * (10 ** tokenDecimals);

        return tokenDecimals;
    }


    function withdrawToken(address token) private {

        // Withdraws the entire available 
        lendingPool.withdraw(token, type(uint).max, msg.sender);
    }
}