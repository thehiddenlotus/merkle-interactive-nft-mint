pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Highly gas efficient Interactive ERC721 with merkle cryptography for presale and free-sale
// Multiple bases used to give user choice in the interactive mint
// by Hidden Lotus Tech

contract MerkleNFT is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter; // Saves gas vs the traditional ERC-721Enumerable

    Counters.Counter private supply;

    bool public paused;
    bool public revealed;
    bool public presale;
    bool public freesale;

    uint256 public constant maxSupply = 8888;

    uint256 public cost = 0.03 ether;

    uint256 public maxMintAmountPerTx = 30;
    uint256 public maxPerPresaleAddress = 9; // It is possible to use non-universal amounts for these limits with the merkle proofs
    uint256 public maxPerFreesaleAddress = 1; // But I have them set up to be universal.
    uint256 public reserveCount;
    uint256 public reserveLimit = 888;

    // withdrawal addresses
    address public constant devAddress =
        0x9C0aC9D88DE0c9AF72Cb7d5Cc4929289110E5BE9;
    // address public constant dev2Address = 0x...;
    // address public constant artistAddress = 0x...;
    address public constant communityAddress =
        0x9C0aC9D88DE0c9AF72Cb7d5Cc4929289110E5BE9;

    bytes32 public presaleMerkle;
    bytes32 public freesaleMerkle;

    string public uriPrefix;
    string public uriSuffix;
    string public uriHidden;

    mapping(address => uint256) public presaleClaimed;
    mapping(address => uint256) public freesaleClaimed;

    constructor(
        string memory _uriHidden,
        bytes32 _presaleMerkle,
        bytes32 _freesaleMerkle
    ) ERC721("MerkleNFT", "HLTNFT") {
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

    modifier mintCompliance(uint256 memory mintCount) {
        require(!paused, "The sale is paused.");
        require(mintCount > 0, "Mint count must be greater than 0.");
        require(
            mintCount <= maxMintAmountPerTx,
            "Invalid mint amount. Extends transaction limit."
        );
        require(
            supply.current() + mintCount <= maxSupply,
            "Would exceed max supply."
        );
        require(
            supply.current() + mintCount <=
                maxSupply - (reserveLimit - reserveCount),
            "Exceeds max supply + reserve."
        );
        _;
    }

    function mintPresale(
        address account,
        uint256 memory mintCount,
        bytes32[] calldata merkleProof
    ) public payable mintCompliance(mintCount) {
        bytes32 node = keccak256(
            abi.encodePacked(account, maxPerPresaleAddress)
        );
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
        _mintLoop(account, mintCount);
        presaleClaimed[account] += mintCount;
    }

    function mintFreesale(
        address account,
        uint256 memory mintCount,
        bytes32[] calldata merkleProof
    ) public mintCompliance(mintCount) {
        bytes32 node = keccak256(
            abi.encodePacked(account, maxPerFreesaleAddress)
        );
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
        _mintLoop(account, mintCount);
        freesaleClaimed[account] += mintCount;
    }

    function mint(uint256 memory mintCount)
        public
        payable
        mintCompliance(mintCount)
    {
        require(!presale, "Only presale minting currently.");
        require(msg.value >= cost * mintCount, "Insufficient funds.");
        _mintLoop(msg.sender, mintCount);
    }

    function mintForAddress(uint256 memory mintCount, address _receiver)
        public
        mintCompliance(mintCount)
        onlyOwner
    {
        require(
            reserveCount + mintCount <= reserveLimit,
            "Exceeds max reserved."
        );
        _mintLoop(_receiver, mintCount);
        reserveCount += mintCount;
    }

    function _mintLoop(address _receiver, uint256 memory mintAmounts)
        internal
    {
        for (uint256 i = 0; i < mintAmounts; i++) {
            supply.increment();
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
            return
                bytes(uriHidden).length > 0
                    ? string(
                        abi.encodePacked(uriHidden, _tokenId, uriSuffix)
                    )
                    : "INVALID";
        }
        return
            bytes(uriPrefix).length > 0
                ? string(
                    abi.encodePacked(
                        uriPrefix,
                        _tokenId.toString(),
                        uriSuffix
                    )
                )
                : "INVALID";
    }

    function totalSupply() public view returns (uint256) {
        return supply.current();
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

        // This function may be frowned upon
    function setReserveLimit(uint256 _limit) public onlyOwner {
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
