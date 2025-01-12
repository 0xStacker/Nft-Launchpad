//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import {Drop} from "./Drop.sol";

contract LaunchFactory{
    uint mintFee = 200000000000000;
    Drop[] public dropList;
    mapping(address => Drop[] _drops) public userDrops;

    function createERC721Drop(string memory _name,
    string memory _symbol,
    uint _maxSupply,
    uint _startTime,
    uint _duration,
    address _owner,
    uint _price,
    uint8 _maxPerWallet
    ) external{
        Drop newDrop = new Drop(_name,
        _symbol,
        _maxSupply,
        _startTime,
        _duration,
        _owner,
        mintFee,
        _price,
        _maxPerWallet);
        dropList.push(newDrop);
        userDrops[_owner].push(newDrop);
       }       
   

    function getDropsByCreator(address _creator) external view returns(Drop[] memory){
        return userDrops[_creator];
    }
        
}