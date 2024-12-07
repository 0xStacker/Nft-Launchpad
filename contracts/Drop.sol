// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import {ERC721} from ".deps/github/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
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
    uint8 public maxPerWallet;
    tokenGate[] public tokenGates;
    publicMint internal _publicMint;
    bool internal enablePublicMint = true;
    using MerkleProof for bytes32[];


    constructor(string memory _name,
    string memory _symbol,
    uint _maxSupply,
    uint _startTime,
    uint _endTime,
    address _owner,   
    address _creator,
    uint _mintFee,
    uint _price,
    uint8 _maxPerWallet) ERC721(_name, _symbol){
        creator = _creator;
        MAX_SUPPLY = _maxSupply;
        startTime = _startTime;
        price = _price;
        maxPerWallet = _maxPerWallet;
        owner = _owner;
        mintFee = _mintFee;
        _publicMint.startTime = _startTime;
        _publicMint.endTime = _endTime;
        _publicMint.price = _price;
        _publicMint.maxPerWallet = _maxPerWallet;
    }

    receive() external payable { }

    fallback() external payable { }


    error NotWhitelisted(address _address);
    error InsufficientFunds(uint _cost);
    error SupplyExceeded(uint maxSupply);
    error InvalidPhase(uint8 _phaseId);

    event SalePaused();
    event Purchase(address _buyer, uint _tokenId, uint _amount);
    event Airdrop(address _to, uint _tokenId, uint _amount);
    event ResumeSale();
    event SetTokenGate(address _token, string _type, uint _requiredAmount);
    

    modifier onlyOwner{
        require(msg.sender == owner, "Not Owner");
        _;
    }

    modifier phaseActive(uint8 _phaseId){
        if (_phaseId == 0){
            require(_publicMint.startTime <= block.timestamp && block.timestamp <= _publicMint.endTime, "Phase Inactive");
        _;
        }

        else{
            uint phaseStartTime = phases[_phaseId].startTime;
            uint phaseEndTime = phases[_phaseId].endTime;
            require(phaseStartTime <= block.timestamp && block.timestamp <= phaseEndTime, "Phase Inactive");
        }

    }    

    modifier isPaused{
        require(!paused, "Sale Is Paused");
        _;
    }


    modifier limit(address _to, uint _amount, uint8 _phaseId){
        if(_phaseId == 0){
            require(balanceOf(_to) + _amount <= maxPerWallet, "Mint Limit Exceeded");
            _;
        }
        else{
            uint8 phaseLimit = phases[_phaseId].maxPerAddress;
            require(balanceOf(_to) + _amount <= phaseLimit, "Mint Limit Exceeded");
            _;
        }
    }

    struct tokenGate{
        address _tokenAddress;
        uint _requiredAmount;
        bool _isFungible;
    }

    struct publicMint{
        uint startTime;
        uint endTime;
        uint price;
        uint maxPerWallet;
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


    enum toggle{ENABLE, DISABLE}
    bool publicMintEnabled;

    // Toggle for Public minting process
    function togglePublicMint(toggle _option) external onlyOwner{
        if(_option == toggle.ENABLE){
            enablePublicMint = true;
        }
        else{
            enablePublicMint = false;
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

    // total supply
    function supply() external view returns(uint){
        return MAX_SUPPLY;
    }


    function getTotalMinted() external view returns(uint){
        return totalMinted;
    }

/**
* @dev Public minting function.
* @param _amount is the amount of nfts to mint
* @param _to is the address to mint the tokens to
* @notice can only mint when public sale has started and the minting process is not paused by the creator
* @notice minting is limited to the maximum amounts allowed 
*/

    function mintPublic(uint _amount, address _to) external payable phaseActive(0) isPaused limit(_to, _amount, 0){
        if (!_canMint(_amount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        uint totalCost = _getCost(_amount);
        if(msg.value < totalCost){
            revert InsufficientFunds(totalCost);
        }
        _mintNft(_to, _amount);
        emit Purchase(_to, tokenId, _amount);
    }


    // function controlledMint(uint _amount, address _to) external payable  isPaused{
    //     uint amountMintable = msg.value / price;
    //     if (!_canMint(_amount)){
    //         uint amountLeft = (MAX_SUPPLY - totalMinted);
    //         if(amountLeft >= maxPerWallet){
    //             amountMintable = maxPerWallet;
    //         } else{
    //             amountMintable = amountLeft;
    //         }
    //     }
    //     uint totalCost = _getCost(amountMintable);
    //     if(msg.value < totalCost){
    //         revert InsufficientFunds(totalCost);
    //     }
    //     _mintNft(_to, amountMintable);
    //     emit Purchase(msg.sender, tokenId, _amount);

    // }

    struct PresalePhase{
        uint8 maxPerAddress;
        string name;
        uint price;
        uint startTime;
        uint endTime;
        bytes32 merkleRoot;
    }
    
    uint8 phaseIds;
    mapping(uint8 => PresalePhase) public phases;
    mapping(uint8 => bool) public phaseCheck;

    /**
    * @dev This function allows the creator to add presale phases
    * @param _phases is an array of phases to be added
    */

    function setPhases(PresalePhase[] memory _phases) external onlyOwner{        
        for(uint8 i; i < _phases.length; i++){
            phases[i + 1] = _phases[i];
            phaseCheck[i + 1] = true;
        }

    }

    /**
    * @dev Allows creator to airdrop NFTs to an account
    * @param _to is the address of the receipeient
    * @param _amount is the amount of NFTs to be airdropped
    * Ensures amount of tokens to be minted does not exceed MAX_SUPPLY*/

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
    function pauseSale() external onlyOwner{
        paused = true;
        emit SalePaused();
    }

    // Resume mint process
    function resumeSale() external onlyOwner{
        paused = false;
        emit ResumeSale();
    }

    // function GatedMint(uint _amount) external payable{
    //     if (!_canMint(_amount)){
    //         revert SupplyExceeded(MAX_SUPPLY);
    //     }

    // }

    // Withdraw funds from contract

    function withdraw(uint _amount) external onlyOwner{
        require(address(this).balance >= _amount, "Insufficient Funds");
        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "Withdrawal Failed");
    }

    /**
    * @dev Check the whitelist status of an account based on merkle proof.
    * @param _proof is a merkle proof to check for verification.
    * @param _amount is the amount of tokens to be minted.
    * @param _phaseId is the presale phase the user is attempting to mint for.
    * @notice If phase is not active, function reverts.
    * @notice If amount exceeds the maximum allowed to be minted per walllet, function reverts.
    */

    function whitelistMint(bytes32[] memory _proof, uint8 _amount, uint8 _phaseId) external phaseActive(_phaseId) isPaused limit(msg.sender, _amount, _phaseId){
        if (!phaseCheck[_phaseId]){
            revert InvalidPhase(_phaseId);
        }

        // PresalePhase memory phase = phases[_phaseId];
        if (!_canMint(_amount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        bool whitelisted = _proof.verify(phases[_phaseId].merkleRoot, keccak256(abi.encodePacked(msg.sender)));
        if(!whitelisted){
            revert NotWhitelisted(msg.sender);
        }
        _mintNft(msg.sender, _amount);
    }


    // Return creator address
    function creatorAddress() public view returns(address){
        return owner;
    }
}