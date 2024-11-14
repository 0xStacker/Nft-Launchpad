// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";

contract Drop is ERC721{
    uint immutable MAX_SUPPLY;
    uint price;
    address immutable owner;
    address immutable creator;
    uint tokenId;
    uint startTime;
    uint royalty;
    bool immutable dynamicPricing;
    bool isSoulbound;


    constructor(string memory _name, string memory _symbol,
     uint _maxSupply, uint _startTime, bool _isSoulbound,
      address _owner, uint _royalty,
       address _creator,
       bool _dynamicPricing) ERC721(_name, _symbol){
        creator = _creator;
        MAX_SUPPLY = _maxSupply;
        startTime = _startTime;
        isSoulbound = _isSoulbound;
        dynamicPricing = _dynamicPricing;
        owner = _owner;
    }

    modifier onlyOwner{
        require(msg.sender == owner, "Not Owner");
        _;
    }

    error InsufficientFunds(uint _cost);

    function mintPublic(uint _amount, address _to) external payable{
        if(msg.value < price){
            revert InsufficientFunds(price);
        }
        for(uint i; i < _amount; i++){
            tokenId += 1;
            _safeMint(_to, tokenId);
        }
        
    }

    function airdrop(address _to) external onlyOwner{
        tokenId += 1;
        _safeMint(_to, tokenId);
    }

    function whitelistMint() external {}

} 