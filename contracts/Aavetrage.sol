//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;


import { ILendingPoolAddressesProvider } from '@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol';
import { ILendingPool } from '@aave/protocol-v2/contracts/interfaces/ILendingPool.sol';
import { AaveProtocolDataProvider } from '@aave/protocol-v2/contracts/misc/AaveProtocolDataProvider.sol';


contract Aavetrage {
    ILendingPoolAddressesProvider private provider;
    AaveProtocolDataProvider private dataProvider;
    ILendingPool private lendingPool;

    constructor(address _provider) public {
        provider = ILendingPoolAddressesProvider(_provider);
        lendingPool = ILendingPool(provider.getLendingPool());

        dataProvider = new AaveProtocolDataProvider(provider);
    }

    function peek() public view returns (AaveProtocolDataProvider.TokenData[] memory) {
        return dataProvider.getAllReservesTokens();
    }
}