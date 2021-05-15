//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.3;


contract Aavetrage {
    address private _testAddress;

    constructor()  {}

    function setAddress(address _newAddress) public {
        _testAddress = _newAddress;
    }


    function viewAddress() public view returns (address) {
        return _testAddress;
    }
}