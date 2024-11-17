// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol";

contract Drop is ERC721{

    uint public immutable MAX_SUPPLY;
    uint public totalMinted;
    uint public price;
    address public immutable owner;
    address public immutable creator;
    uint private tokenId;
    uint private startTime;
    uint private royalty;
    uint public mintFee;
    bool public paused;
    // bool isSoulbound;
    // bool cooldown;
    uint public maxPerWallet;
    using MerkleProof for bytes32[];

    constructor(string memory _name, string memory _symbol,
     uint _maxSupply, uint _startTime,
      address _owner,
       address _creator, uint _mintFee, uint _price, uint _maxPerWallet) ERC721(_name, _symbol){
        creator = _creator;
        MAX_SUPPLY = _maxSupply;
        startTime = _startTime;
        price = _price;
        maxPerWallet = _maxPerWallet;
        owner = _owner;
        mintFee = _mintFee;
    }

    event SalePaused();
    event Purchase(address _buyer, uint _tokenId, uint _amount);
    event Airdrop(address _to, uint _tokenId, uint _amount);
    event ResumeSale();

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

    function _canMint(uint _amount) internal view returns (bool){
        if (totalMinted + _amount > MAX_SUPPLY){
            return false;
        } else{
            return true;
        }
    }

    error InsufficientFunds(uint _cost);
    error SupplyExceeded(uint maxSupply);

    function _getCost(uint amount) internal view returns (uint cost){
        return (price * amount) + mintFee;
    }

    function _mintNft(address _to, uint _amount) internal {    
        IERC721 nft = IERC721(address(this));
        require(nft.balanceOf(_to) + _amount <= maxPerWallet, "Mint Limit Exceeded");
        for(uint i; i < _amount; i++){
            tokenId += 1;
            totalMinted += 1;
            _safeMint(_to, tokenId);
        }

    }

    function mintPublic(uint _amount) external saleStarted isPaused payable{
        if (!_canMint(_amount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }

        uint totalCost = _getCost(_amount);
        if(msg.value < totalCost){
            revert InsufficientFunds(totalCost);
        }
        _mintNft(msg.sender, _amount);
        emit Purchase(msg.sender, tokenId, _amount);
    }

    function controlledMint(uint _amount) external saleStarted isPaused payable{
        uint amountMintable = _amount;
        if (!_canMint(_amount)){
            uint amountLeft = (MAX_SUPPLY - totalMinted);
            if(amountLeft >= maxPerWallet){
                amountMintable = maxPerWallet;
            } else{
                amountMintable = amountLeft;
            }
        }
        uint totalCost = _getCost(amountMintable);
        if(msg.value < totalCost){
            revert InsufficientFunds(totalCost);
        }
        _mintNft(msg.sender, amountMintable);
        emit Purchase(msg.sender, tokenId, _amount);

    }


    function airdrop(address _to, uint _amount) external onlyOwner{
        if(!_canMint(_amount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        _mintNft(_to, _amount);
        emit Airdrop(_to, tokenId, _amount);
    }

    function batchAirdrop(address[] calldata _receipients, uint _amountPerAddress) external onlyOwner{
        uint totalAmount = _amountPerAddress * _receipients.length;
        if (!_canMint(totalAmount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        for(uint i; i < _receipients.length; i++){
            _mintNft(_receipients[i], _amountPerAddress);
            emit Airdrop(_receipients[i], tokenId, _amountPerAddress);
        }
    }

    function pauseSale() external saleStarted onlyOwner{
        paused = true;
        emit SalePaused();
    }

    function resumeSale() external saleStarted onlyOwner{
        paused = false;
        emit ResumeSale();
    }
    error NotWhitelisted(address _address);


    function whitelistMint(bytes32[] memory _proof, bytes32 _root, bytes32 _leaf, uint _amount) external saleStarted isPaused{
        if (!_canMint(_amount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        bool whitelisted = _proof.verify(_root, _leaf);
        if(!whitelisted){
            revert NotWhitelisted(msg.sender);
        }
        _mintNft(msg.sender, _amount);
    }



} 