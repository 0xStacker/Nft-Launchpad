//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import {Drop} from "./Drop.sol";
import {PresaleLib} from "./PresaleLib.sol";

contract LaunchFactory{
    uint mintFee = 200000000000000;
    address[] public dropList;
    mapping(address => address[] _drops) public userDrops;

    /*
        string memory _name,
    string memory _symbol,
    uint _maxSupply,
    uint _startTime,
    uint _duration,
    address _owner,   
    uint _mintFee,
    uint _price,
    uint8 _maxPerWallet,
    bool _includePresale,
    PresaleLib.PresalePhase[] memory _presalePhases   
    */
    
    function createERC721Drop(string memory _name,
    string memory _symbol,
    uint _maxSupply,
    uint _startTime,
    uint _duration,
    address _owner,
    uint _price,
    uint8 _maxPerWallet
    ) external returns(address){
        Drop newDrop = new Drop(_name,
        _symbol,
        _maxSupply,
        _startTime,
        _duration,
        _owner,
        mintFee,
        _price,
        _maxPerWallet);
        dropList.push(address(newDrop));
        userDrops[_owner].push(address(newDrop));
        return address(newDrop);
       }
       
    
    function getDropsByCreator(address _creator) external view returns(address[] memory){
        return userDrops[_creator];
    }
    
    
}