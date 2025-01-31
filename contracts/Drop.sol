// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
import {ERC721} from ".deps/github/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from ".deps/github/OpenZeppelin/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {PresaleLib} from "./PresaleLib.sol";


/**
* @dev Implementation of an ERC721 drop.

*/

contract Drop is ERC721{
    
    uint public immutable MAX_SUPPLY;
    uint public totalMinted;
    uint8 constant PHASELIMIT = 5;
    uint private immutable price;
    address public immutable owner;
    uint private tokenId;
    uint private royalty;
    uint public mintFee;
    bool public paused;
    PublicMint internal _publicMint;
    bool internal enablePublicMint = true;
    uint8 internal phaseIds;
    // Sequential phase identities, 0 represents the public minting phase.
    mapping(uint8 => PresaleLib.PresalePhase) public phases;
    mapping(uint8 => bool) public phaseCheck;
    PresaleLib.PresalePhase[] internal _returnablePhases;
    
    using MerkleProof for bytes32[];


    /**
    * @dev Initialize contract by setting necessary data.
    * @param _name is the name of the collection.
    * @param _symbol is the collection symbol.
    * @param _maxSupply is the maximum supply of the collection.
    * @param _startTime is the start time for the public mint.
    * @param _duration is the mint duration for the public mint.
    * @param _owner is the address of the collection owner
    * @param _mintFee is the platform mint fee.
    * @param _price is the mint price per nft for public mint.
    * @param _maxPerWallet is the maximum nfts allowed to be minted by a wallet during the public mint
 
    */

    constructor(string memory _name,
    string memory _symbol,
    uint _maxSupply,
    uint _startTime,
    uint _duration,
    address _owner,   
    uint _mintFee,
    uint _price,
    uint8 _maxPerWallet) ERC721(_name, _symbol){
        MAX_SUPPLY = _maxSupply;
        price = _price;
        // Ensure that owner is an EOA and not zero address
        require(_owner.code.length == 0 && _owner != address(0), "Invalid Adress");
        owner = _owner;
        mintFee = _mintFee;
        _publicMint.startTime = block.timestamp + _startTime;
        _publicMint.endTime = block.timestamp + _startTime + _duration;
        _publicMint.price = _price;
        _publicMint.maxPerWallet = _maxPerWallet;
    }

    receive() external payable { }

    fallback() external payable { }

    error NotWhitelisted(address _address);
    error InsufficientFunds(uint _cost);
    error SupplyExceeded(uint maxSupply);
    error InvalidPhase(uint8 _phaseId);
    error ZeroAddress();
    error PurchaseFailed();
    error NotCreator();
    error NotOwner();
    error SaleIsPaused();
    error WithdrawalFailed();
    error MaxPhaseLimit();


    event SalePaused();
    event Purchase(address _buyer, uint _tokenId, uint _amount);
    event Airdrop(address _to, uint _tokenId, uint _amount);
    event ResumeSale();
    event SetTokenGate(address _token, string _type, uint _requiredAmount);
    event SetPhase(uint _phaseCount);    
    event PublicMintEnabled();
    event PublicMintDisabled();
    event WithdrawFunds(uint _amount);
    event AddPresalePhase(string _phaseName, uint8 _phaseId);
    event RemovePresalePhase(string _phaseName, uint8 _phaseId);
    event BatchAirdrop(address[] _receipients, uint _amount);

    
    // Enforce Creator priviledges
    modifier onlyCreator{
        if (msg.sender != owner){
            revert NotCreator();}
        _;
    }

    // Enforce owner priviledges
    modifier tokenOwner(uint _tokenId){
        if(msg.sender != ownerOf(_tokenId)){
            revert NotOwner();}
        _;
    }

    // Block minting unless phase is active
    modifier phaseActive(uint8 _phaseId){
        if (_phaseId == 0){
            require(_publicMint.startTime <= block.timestamp && block.timestamp <= _publicMint.endTime, "Phase Inactive");
        }

        else{
            uint phaseStartTime = phases[_phaseId].startTime;
            uint phaseEndTime = phases[_phaseId].endTime;
            require(phaseStartTime <= block.timestamp && block.timestamp <= phaseEndTime, "Phase Inactive");
        }
        _;
    }

    // Allows owner to pause minting at any phase.
    modifier isPaused{
        if(paused){
            revert SaleIsPaused();
        }
        _;
    }

    /**
    * @dev Enforce phase minting limit per address.  
    */
    modifier limit(address _to, uint _amount, uint8 _phaseId){
        if(_phaseId == 0){
            require(balanceOf(_to) + _amount <= _publicMint.maxPerWallet, "Mint Limit Exceeded");
        }
        else{
            uint8 phaseLimit = phases[_phaseId].maxPerAddress;
            require(balanceOf(_to) + _amount <= phaseLimit, "Mint Limit Exceeded");
        }
        _;
    }


    /**
    * @dev Holds mint details for the public/general mint
    */
    struct PublicMint{
        uint startTime;
        uint endTime;
        uint price;
        uint maxPerWallet;
    }

    // enum toggle{ENABLE, DISABLE}
    // bool publicMintEnabled;

    /**
    * @dev Allows creator to enable or disable public mint.
    * useful if creator only wants a whitelisted sale.
    */
    // function togglePublicMint(toggle _option) external onlyCreator{
    //     if(_option == toggle.ENABLE){
    //         enablePublicMint = true;
    //         emit PublicMintEnabled();
    //     }
    //     else{
    //         enablePublicMint = false;
    //         emit PublicMintDisabled();
    //     }
    // }


    /**
    * @dev Public minting function.
    * @param _amount is the amount of nfts to mint
    * @param _to is the address to mint the tokens to
    * @notice can only mint when public sale has started and the minting process is not paused by the creator
    * @notice minting is limited to the maximum amounts allowed on the public mint phase.
    */

    function mintPublic(uint _amount, address _to) external payable phaseActive(0) limit(_to, _amount, 0){
        if (_to == address(0)){
            revert ZeroAddress();
        }

        if (!_canMint(_amount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }

        uint totalCost = _getCost(0, _amount);
        if(msg.value < totalCost){
            revert InsufficientFunds(totalCost);
        }
        _mintNft(_to, _amount);
        emit Purchase(_to, tokenId, _amount);
    }

    
    /**
    * @dev adds new presale phase for contract
    * @param _phase is the new phase to be added
    * @notice phases are identified sequentially using numbers, starting from 1.
    */
    function addPresalePhase(PresaleLib.PresalePhaseIn calldata _phase) external onlyCreator{

        uint8 phaseId = phaseIds + 1;
        PresaleLib.PresalePhase memory phase = PresaleLib.PresalePhase({
            name: _phase.name,
            startTime: block.timestamp + _phase.startTime,
            endTime: block.timestamp + _phase.endTime,
            maxPerAddress: _phase.maxPerAddress,
            price: _phase.price,
            merkleRoot: _phase.merkleRoot,
            phaseId: phaseId});

            phases[phaseId] = phase;
            phases[phaseId].startTime = phases[phaseId].startTime + block.timestamp;
            phases[phaseId].endTime = phases[phaseId].endTime + block.timestamp;
            phaseCheck[phaseId] = true;
            _returnablePhases.push(phase);
            phaseIds += 1;
            if(_returnablePhases.length > PHASELIMIT){
                revert MaxPhaseLimit();
            }
            emit AddPresalePhase(_phase.name, phaseId);
    }

    /**
    * @dev Remove presale phase
    * @param _phaseId is the identifier for the phase being removed
    */

    function removePhase(uint8 _phaseId) external onlyCreator{
        if (!phaseCheck[_phaseId]){
            revert InvalidPhase(_phaseId);
        }

        PresaleLib.PresalePhase[] memory returnablePhases = _returnablePhases;
        delete _returnablePhases;
        for (uint8 i; i < returnablePhases.length; i++){
            if (returnablePhases[i].phaseId != _phaseId){
                _returnablePhases.push(returnablePhases[i]);
            }
        }
        delete phases[_phaseId];
        phaseCheck[_phaseId] = false;
        emit RemovePresalePhase(phases[_phaseId].name, _phaseId);
    }

    // getter for presale phase data
    function getPresaleData() external view returns(PresaleLib.PresalePhase[] memory){
        return _returnablePhases;
    }

    // getter for public mint data
    function getPublicMintData() external view returns(PublicMint memory){
        return _publicMint;
    }

    /**
    * @dev Allows creator to airdrop NFTs to an account
    * @param _to is the address of the receipeient
    * @param _amount is the amount of NFTs to be airdropped
    * Ensures amount of tokens to be minted does not exceed MAX_SUPPLY*/

    function airdrop(address _to, uint _amount) external onlyCreator{
        if (_to == address(0)){
            revert ZeroAddress();
        }
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
    function batchAirdrop(address[] calldata _receipients, uint _amountPerAddress) external onlyCreator{
        uint totalAmount = _amountPerAddress * _receipients.length;
        if (!_canMint(totalAmount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        for(uint i; i < _receipients.length; i++){
            if (_receipients[i] == address(0)){
                revert ZeroAddress();
            }
            _mintNft(_receipients[i], _amountPerAddress);
        }
        emit BatchAirdrop(_receipients, _amountPerAddress);
    }
    
    // Pause mint process
    function pauseSale() external onlyCreator{
        paused = true;
        emit SalePaused();
    }

    // Resume mint process
    function resumeSale() external onlyCreator{
        paused = false;
        emit ResumeSale();
    }

    // Withdraw funds from contract
    function withdraw(uint _amount) external onlyCreator{
        if (address(this).balance < _amount){
            revert InsufficientFunds(_amount);
        }
        (bool success, ) = payable(owner).call{value: _amount}("");
        if (!success){
            revert WithdrawalFailed();
        }
        emit WithdrawFunds(_amount);
    }

    /**
    * @dev Check the whitelist status of an account based on merkle proof.
    * @param _proof is a merkle proof to check for verification.
    * @param _amount is the amount of tokens to be minted.
    * @param _phaseId is the presale phase the user is attempting to mint for.
    * @notice If phase is not active, function reverts.
    * @notice If amount exceeds the maximum allowed to be minted per walllet, function reverts.
    */

    function whitelistMint(bytes32[] memory _proof, uint8 _amount, uint8 _phaseId) external payable phaseActive(_phaseId) limit(msg.sender, _amount, _phaseId){
        if (!phaseCheck[_phaseId]){
            revert InvalidPhase(_phaseId);
        }
        // PresalePhase memory phase = phases[_phaseId];
        if (!_canMint(_amount)){
            revert SupplyExceeded(MAX_SUPPLY);
        }
        
        // get mint cost
        uint totalCost = _getCost(_phaseId, _amount);
        if (msg.value < totalCost){
            revert InsufficientFunds(totalCost);
        }
        // verify whitelist
        bool whitelisted = _proof.verify(phases[_phaseId].merkleRoot, keccak256(abi.encodePacked(msg.sender))); 
        if(whitelisted == false){
            revert NotWhitelisted(msg.sender);
        }
        _mintNft(msg.sender, _amount);
    }


    /**
    * @dev Allows owner to burn their nft
    */
    function burn(uint _tokenId) tokenOwner(_tokenId) external{
        _burn(tokenId);
    }

      // total supply
    function supply() external view returns(uint){
        return MAX_SUPPLY;
    }
 
    /**
    * @dev Checks if a certain amount of token can be minted. 
    * @param _amount is the amount of tokens to be minted.
    * @notice Ensures that minting _amount tokens does not cause the total minted tokens to exceed max supply.
    */
    function _canMint(uint _amount) internal view returns (bool){
        if (totalMinted + _amount > MAX_SUPPLY){
            return false;
        } else{
            return true;
        }
    }


    /**
    * @dev Compute the cost of minting a certain amount of tokens.
    * @param _amount is the amount of tokens to be minted.
    */
    function _getCost(uint8 _phaseId, uint _amount) public view returns (uint cost){
        if (_phaseId == 0){
            return (price * _amount) + mintFee;
        }

        else{
            return (phases[_phaseId].price * _amount) + mintFee;
        }

    }

    /**
     * @dev Safe minting function that will mint n amount of tokens to an address.
     * @param _to is the address of the receipient.
     * @param _amount is the amount of tokens to be minted.
    */

    function _mintNft(address _to, uint _amount) internal isPaused {  
        if (_to == address(0)){
            revert ZeroAddress();
        }

        (bool success,) = payable(owner).call{value: msg.value}("");
        if (!success){
            revert PurchaseFailed();
        }
 
        for(uint i; i < _amount; i++){
            tokenId += 1;
            totalMinted += 1;
            _safeMint(_to, tokenId);
        }
    }
}