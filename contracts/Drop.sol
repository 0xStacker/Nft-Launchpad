// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";

contract Drop is ERC721{
    uint public immutable MAX_SUPPLY;
    uint public totalMinted;
    uint public price;
    address public immutable owner;
    address public immutable creator;
    uint private tokenId;
    uint private startTime;
    uint private royalty;
    uint mintFee;
    bool public paused;
    bool isSoulbound;


    constructor(string memory _name, string memory _symbol,
     uint _maxSupply, uint _startTime,
      address _owner,
       address _creator, uint _mintFee) ERC721(_name, _symbol){
        creator = _creator;
        MAX_SUPPLY = _maxSupply;
        startTime = _startTime;
        // dynamicPricing = _dynamicPricing;
        owner = _owner;
        mintFee = _mintFee;
    }

    modifier onlyOwner{
        require(msg.sender == owner, "Not Owner");
        _;
    }

    modifier saleStarted{
        require(block.timestamp >= startTime, "SaleNotStarted");
        _;
    }    

    modifier isPaused{
        require(!paused, "Sale Is Paused");
        _;
    }

    error InsufficientFunds(uint _cost);
    error SupplyExceeded(uint maxSupply);

    function _getCost(uint amount) internal view returns (uint cost){
        
        return (price * amount) + mintFee;
    }

    function _mintNft(address _to) internal {
        tokenId += 1;
        totalMinted += 1;
        _safeMint(_to, tokenId);
    }


    function mintPublic(uint _amount, address _to) external saleStarted isPaused payable{

        uint totalCost = _getCost(_amount);
        if(msg.value < totalCost){
            revert InsufficientFunds(totalCost);
        }
        if (totalMinted + _amount > MAX_SUPPLY){
            revert SupplyExceeded(MAX_SUPPLY);
            }

        for(uint i; i < _amount; i++){
            _mintNft(_to);
        }
        
    }

    function airdrop(address _to, uint _amount) external onlyOwner{
        if (totalMinted + _amount > MAX_SUPPLY){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        for(uint i; i < _amount; i++){
            _mintNft(_to);
        }
    }

    function batchAirdrop(address[] calldata _receipients, uint _amountPerAddress) external onlyOwner{
        if (totalMinted + (_amountPerAddress * _receipients.length) > MAX_SUPPLY){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        for(uint i; i < _receipients.length; i++){
            for(uint j; j < _amountPerAddress; j++){
                _mintNft(_receipients[i]);
            }
        }

    }

    function pauseSale() external saleStarted onlyOwner{
        paused = true;
    }


    function whitelistMint() external {}

} 