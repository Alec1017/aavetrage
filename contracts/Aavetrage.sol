//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;


import { ILendingPoolAddressesProvider } from '@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol';
import { ILendingPool } from '@aave/protocol-v2/contracts/interfaces/ILendingPool.sol';
import { DataTypes } from '@aave/protocol-v2/contracts/protocol/libraries/types/DataTypes.sol';


contract Aavetrage {
    ILendingPoolAddressesProvider private provider;
    ILendingPool private lendingPool;

    constructor(address _provider) public {
        provider = ILendingPoolAddressesProvider(_provider);
        lendingPool = ILendingPool(provider.getLendingPool());
    }


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

        return (bestBorrowToken, bestSupplyToken);
    }
}