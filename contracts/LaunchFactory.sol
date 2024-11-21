//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import "./Drop.sol";

contract LaunchFactory{
    uint mintFee = 200000000000000;
    
    function createERC721Drop(string memory _name, string memory _symbol,
     uint _maxSupply, uint _startTime, uint _price, uint _maxPerWallet) external returns(address){
        Drop newDrop = new Drop(_name, _symbol, _maxSupply, _startTime,msg.sender, msg.sender,
        mintFee, _price, _maxPerWallet);
        return address(newDrop);
       }
}