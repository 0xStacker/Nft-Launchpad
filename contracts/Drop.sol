// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from ".deps/github/OpenZeppelin/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

interface IERC20{
    function balanceOf(address _account) external view returns(uint);
}


contract Drop is ERC721{
    uint public immutable MAX_SUPPLY;
    uint public totalMinted;
    uint private immutable price;
    address public immutable owner;
    address public immutable creator;
    uint private tokenId;
    uint private startTime;
    uint private royalty;
    uint public mintFee;
    bool public paused;
    uint public maxPerWallet;
    tokenGate[] public tokenGates;


    using MerkleProof for bytes32[];
    constructor(string memory _name,
    string memory _symbol,
    uint _maxSupply,
    uint _startTime,
    address _owner,   
    address _creator,
    uint _mintFee,
    uint _price,
    uint _maxPerWallet) ERC721(_name, _symbol){
        creator = _creator;
        MAX_SUPPLY = _maxSupply;
        startTime = _startTime;
        price = _price;
        maxPerWallet = _maxPerWallet;
        owner = _owner;
        mintFee = _mintFee;
    }

    receive() external payable { }

    fallback() external payable { }


    error NotWhitelisted(address _address);

    event SalePaused();
    event Purchase(address _buyer, uint _tokenId, uint _amount);
    event Airdrop(address _to, uint _tokenId, uint _amount);
    event ResumeSale();
    event SetTokenGate(address _token, string _type, uint _requiredAmount);
    

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

    modifier limit(address _to, uint _amount){
        require(balanceOf(_to) + _amount <= maxPerWallet, "Mint Limit Exceeded");
        _;
    }

    struct tokenGate{
        address _tokenAddress;
        uint _requiredAmount;
        bool _isFungible;
    }

    function _canMint(uint _amount) internal view returns (bool){
        if (totalMinted + _amount > MAX_SUPPLY){
            return false;
        } else{
            return true;
        }
    }

    
    function _getCost(uint amount) internal view returns (uint cost){
        return (price * amount) + mintFee;
    }

    function _mintNft(address _to, uint _amount) internal {  
        (bool success,) = payable(creator).call{value: msg.value}("");
        require(success, "Purchase Failed");  
        for(uint i; i < _amount; i++){
            tokenId += 1;
            totalMinted += 1;
            _safeMint(_to, tokenId);
        }

    }


    function setFungibleTokenGate(address _allowedToken, uint _requiredAmount) external onlyOwner{
        require (_allowedToken != address(0), "No Address Provided;");
        require(_allowedToken.code.length > 0, "Not a token contract");
        tokenGate storage newTokenGate = tokenGates.push();
        newTokenGate._tokenAddress = _allowedToken;
        newTokenGate._requiredAmount = _requiredAmount;
        newTokenGate._isFungible = true;
        emit SetTokenGate(_allowedToken, "ERC20", _requiredAmount);
    }

    function setNftGate(address _allowedToken, uint _requiredAmount) external onlyOwner{
            require (_allowedToken != address(0), "No Address Provided;");
            require(_allowedToken.code.length > 0, "Not a token contract");
            tokenGate storage newTokenGate = tokenGates.push();
            newTokenGate._tokenAddress = _allowedToken;
            newTokenGate._requiredAmount = _requiredAmount;
            emit SetTokenGate(_allowedToken, "NFT", _requiredAmount);
    }

    function supply() external view returns(uint){
        return MAX_SUPPLY;
    }

    function checkPaused() external view returns (bool){
        return paused;
    }

    function getMinted() external view returns(uint){
        return totalMinted;
    }


    error InsufficientFunds(uint _cost);
    error SupplyExceeded(uint maxSupply);


    function mintPublic(uint _amount, address _to) external payable saleStarted isPaused limit(_to, _amount){
        if (!_canMint(_amount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        uint totalCost = _getCost(_amount);
        if(msg.value < totalCost){
            revert InsufficientFunds(totalCost);
        }
        _mintNft(_to, _amount);
        // require(success, "Purchase Failed");
        emit Purchase(_to, tokenId, _amount);
    }

    /**
    * @dev Allows users to mint */


    function controlledMint(uint _amount, address _to) external payable saleStarted isPaused{
        uint amountMintable = msg.value / price;
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
        _mintNft(_to, amountMintable);
        emit Purchase(msg.sender, tokenId, _amount);

    }

    /**
    * @dev Allows creator to airdrop NFTs to an account
    * @param _to is the address of the receipeient
    * @param _amount is the amount of NFTs to be airdropped
    * Ensures amount to be minted does not exceed MAX_SUPPLY*/

    function airdrop(address _to, uint _amount) external{
        if(!_canMint(_amount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        _mintNft(_to, _amount);
        emit Airdrop(_to, tokenId, _amount);
    }
    
    /**
    * @dev Allows the creator to airdrop NFT to multiple addresses at once.
    * @param _receipients is the list of accounts to mint NFT for.
    * @param _amountPerAddress is the amount of tokens to be minted per addresses.
    * Ensures total amount of NFT to be minted does not exceed MAX_SUPPLY.
    * */
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
    
    // Pause mint process
    function pauseSale() external saleStarted onlyOwner{
        paused = true;
        emit SalePaused();
    }

    // Resume mint process

    function resumeSale() external saleStarted onlyOwner{
        paused = false;
        emit ResumeSale();
    }

    function GatedMint(uint _amount) external payable{
        if (!_canMint(_amount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }

    }

    /**
    * @dev Check the whitelist status of an account based on merkle proof.
    * @param _proof is a merkle proof to check for verification.
    * @param _root is a merkle root generated from the merkle tree.
    * @param _amount is the amount of tokens to be mintes
    * If amount exceeds the maximum allowed to be minted per walllet, function reverts.
    */

    function whitelistMint(bytes32[] memory _proof, bytes32 _root, uint _amount) external saleStarted isPaused limit(msg.sender, _amount){
        if (!_canMint(_amount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        bool whitelisted = _proof.verify(_root, keccak256(abi.encodePacked(msg.sender)));
        if(!whitelisted){
            revert NotWhitelisted(msg.sender);
        }
        _mintNft(msg.sender, _amount);
    }


    // Creator address
    function creatorAddress() public view returns(address){
        return owner;
    }
}