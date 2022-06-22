pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Highly gas efficient Interactive ERC721 with merkle cryptography for presale and free-sale
// Multiple bases used to give user choice in the interactive mint
// by Hidden Lotus Tech

contract MerkleInteractiveNFT is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter; // Saves gas vs the traditional ERC-721Enumerable 

    Counters.Counter private supply;
    Counters.Counter private baseOneSupply;
    Counters.Counter private baseTwoSupply;
    Counters.Counter private baseThreeSupply;

    bool public paused;
    bool public revealed;
    bool public presale;
    bool public freesale;

    uint256 public constant maxSupply = 8888;
    uint256 public constant baseOneMaxSupply = 3333;
    uint256 public constant baseTwoMaxSupply = 3333;
    uint256 public constant baseThreeMaxSupply = 2222;

    uint256 public cost = 0.03 ether;

    uint256 public maxMintAmountPerTx = 30; 
    uint256 public maxPerPresaleAddress = 9; // It is possible to use non-universal amounts for these limits with the merkle proofs
    uint256 public maxPerFreesaleAddress = 1; // But I have them set up to be universal. These values must match in the script as well.
    uint256 public reserveCount;
    uint256 public reserveLimit = 888;
    
    // withdrawal addresses
    address public constant devAddress = 0x9C0aC9D88DE0c9AF72Cb7d5Cc4929289110E5BE9;
    // address public constant dev2Address = 0x...;
    // address public constant artistAddress = 0x...;
    address public constant communityAddress = 0x9C0aC9D88DE0c9AF72Cb7d5Cc4929289110E5BE9;

    bytes32 public presaleMerkle;
    bytes32 public freesaleMerkle;

    string public uriPrefix;
    string public uriSuffix;
    string public uriHidden;

    mapping(address => uint256) public presaleClaimed;
    mapping(address => uint256) public freesaleClaimed;

    mapping(uint256 => uint256) public tokenIdsToBase; // used to keep track of the bases chosen for each mint to build the metadata 

    constructor(
        string memory _uriHidden, 
        bytes32 _presaleMerkle, 
        bytes32 _freesaleMerkle
    )
        ERC721("MerkleInteractiveNFT", "HLTINFT")
    {
        uriHidden = _uriHidden;
        presaleMerkle = _presaleMerkle;
        freesaleMerkle = _freesaleMerkle;
        uriPrefix = "UNREVEALED";
        uriSuffix = ".json";
        reserveCount = 0;
        paused = true;
        revealed = false;
        presale = true;
        freesale = true;
    }

    modifier mintCompliance(uint256[3] memory mintAmounts) {
        uint256 mintCount = (mintAmounts[0] + mintAmounts[1] + mintAmounts[2]);
        require(mintCount > 0, "Mint count must be greater than 0.");
        require(
            supply.current() + mintCount <= maxSupply,
            "Would exceed max supply."
        );
        require(
            supply.current() + mintCount <= maxSupply - (reserveLimit - reserveCount),
            "Exceeds max supply + reserve."
        );
        require(
            baseOneMaxSupply >= baseOneSupply.current() + mintAmounts[0],
            "Not enough base one left."
        );
        require(
            baseTwoMaxSupply >= baseTwoSupply.current() + mintAmounts[1],
            "Not enough base two left."
        );
        require(
            baseThreeMaxSupply >= baseThreeSupply.current() + mintAmounts[2],
            "Not enough base three left."
        );
        _;
    }

    modifier publicCompliance(uint256[3] memory mintAmounts) {
        uint256 mintCount = (mintAmounts[0] + mintAmounts[1] + mintAmounts[2]);
        require(!paused, "The sale is paused.");
        require(
            mintCount <= maxMintAmountPerTx,
            "Invalid mint amount. Extends transaction limit."
        );
        _;
    }

    function mintPresale(
        address account,
        uint256[3] memory mintAmounts,
        bytes32[] calldata merkleProof
    ) public payable mintCompliance(mintAmounts) publicCompliance(mintAmounts) {
        bytes32 node = keccak256(
            abi.encodePacked(account, maxPerPresaleAddress)
        );
        uint256 mintCount = (mintAmounts[0] + mintAmounts[1] + mintAmounts[2]);
        require(presale, "No presale minting currently.");
        require(msg.value >= cost * mintCount, "Insufficient funds.");
        require(
            presaleClaimed[account] + mintCount <= maxPerPresaleAddress,
            "Exceeds max mints for presale."
        );
        require(
            MerkleProof.verify(merkleProof, presaleMerkle, node),
            "Invalid proof."
        );
        _mintLoop(account, mintAmounts);
        presaleClaimed[account] += mintCount;
    }

    function mintFreesale(
        address account,
        uint256[3] memory mintAmounts,
        bytes32[] calldata merkleProof
    ) public mintCompliance(mintAmounts) publicCompliance(mintAmounts) {
        bytes32 node = keccak256(
            abi.encodePacked(account, maxPerFreesaleAddress)
        );
        uint256 mintCount = (mintAmounts[0] + mintAmounts[1] + mintAmounts[2]);
        require(freesale, "No freesale minting currently."); 
        require(mintCount == 1, "Only 1 free.");
        require(
            freesaleClaimed[account] + mintCount <= maxPerFreesaleAddress,
            "Exceeds max mints for presale."
        );
        require(
            MerkleProof.verify(merkleProof, freesaleMerkle, node),
            "Invalid proof."
        );
        _mintLoop(account, mintAmounts);
        freesaleClaimed[account] += mintCount;
    }

    function mint(uint256[3] memory mintAmounts)
        public
        payable
        mintCompliance(mintAmounts)
        publicCompliance(mintAmounts) 
    {
        uint256 mintCount = (mintAmounts[0] + mintAmounts[1] + mintAmounts[2]);
        require(!presale, "Only presale minting currently.");
        require(msg.value >= cost * mintCount, "Insufficient funds.");
        _mintLoop(msg.sender, mintAmounts);
    }

    function mintForAddress(uint256[3] memory mintAmounts, address _receiver)
        public
        mintCompliance(mintAmounts)
        onlyOwner
    {
        uint256 mintCount = (mintAmounts[0] + mintAmounts[1] + mintAmounts[2]);
        require(
            reserveCount + mintCount <= reserveLimit,
            "Exceeds max reserved."
        );
        _mintLoop(_receiver, mintAmounts);
        reserveCount += mintCount;
    }

    function _mintLoop(address _receiver, uint256[3] memory mintAmounts)
        internal
    {
        for (uint256 i = 0; i < mintAmounts[0]; i++) {
            supply.increment();
            baseOneSupply.increment();
            tokenIdsToBase[supply.current()] = 0;
            _safeMint(_receiver, supply.current());
        }
        for (uint256 i = 0; i < mintAmounts[1]; i++) {
            supply.increment();
            baseTwoSupply.increment();
            tokenIdsToBase[supply.current()] = 1;
            _safeMint(_receiver, supply.current());
        }
        for (uint256 i = 0; i < mintAmounts[2]; i++) {
            supply.increment();
            baseThreeSupply.increment();
            tokenIdsToBase[supply.current()] = 2;
            _safeMint(_receiver, supply.current());
        }
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token."
        );
        if (revealed == false) {
            string memory baseId;
            string memory currentHiddenURI = uriHidden;
            if (tokenIdsToBase[_tokenId] == 0) {
                baseId = "baseOne";
            } else if (tokenIdsToBase[_tokenId] == 1) {
                baseId = "baseTwo";
            } else {
                baseId = "baseThree";
            }
            return
                bytes(currentHiddenURI).length > 0
                    ? string(
                        abi.encodePacked(currentHiddenURI, baseId, uriSuffix)
                    )
                    : "INVALID";
        }
        string memory currentBaseURI = uriPrefix;
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        uriSuffix
                    )
                )
                : "INVALID";
    }

    function totalSupply() public view returns (uint256) {
        return supply.current();
    }

    function baseOneTotalSupply() public view returns (uint256) {
        return baseOneSupply.current();
    }

    function baseTwoTotalSupply() public view returns (uint256) {
        return baseTwoSupply.current();
    }

    function baseThreeTotalSupply() public view returns (uint256) {
        return baseThreeSupply.current();
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex = 0;

        while (
            ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply
        ) {
            address currentTokenOwner = ownerOf(currentTokenId);
            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;
                ownedTokenIndex++;
            }
            currentTokenId++;
        }
        return ownedTokenIds;
    }

    function setPresaleMerkle(bytes32 newRoot) public onlyOwner {
        presaleMerkle = newRoot;
    }

    function setFreesaleMerkle(bytes32 newRoot) public onlyOwner {
        freesaleMerkle = newRoot;
    }

    function setUriPrefix(string memory newUriPrefix) public onlyOwner {
        uriPrefix = newUriPrefix;
    }

    function setUriSuffix(string memory newUriSuffix) public onlyOwner {
        uriSuffix = newUriSuffix;
    }

    function setUriHidden(string memory newUriHidden) public onlyOwner {
        uriHidden = newUriHidden;
    }

    function setCost(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    function setReserveLimit(uint256 _limit) public onlyOwner { // This function may be frowned upon
        reserveLimit = _limit;
    }

    function setMaxPerFreesaleAddress(uint256 _maxPerFreesaleAddress)
        public
        onlyOwner
    {
        maxPerFreesaleAddress = _maxPerFreesaleAddress;
    }

    function setMaxPerPresaleAddress(uint256 _maxPerPresaleAddress)
        public
        onlyOwner
    {
        maxPerPresaleAddress = _maxPerPresaleAddress;
    }

    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx)
        public
        onlyOwner
    {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function setPresale(bool _state) public onlyOwner {
        presale = _state;
    }

    function setFreesale(bool _state) public onlyOwner {
        freesale = _state;
    }

    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Insufficent balance");
        _widthdraw(devAddress, ((balance * 15) / 100));
        // _widthdraw(dev2Address, ((balance * 5) / 100));
        // _widthdraw(artistAddress, ((balance * 5) / 100));
        _widthdraw(communityAddress, address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Failed to widthdraw Ether");
    }
}
