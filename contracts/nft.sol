import "@openzeppelin/contracts/access/Ownable.sol";
import "./erc5058.sol";

contract nft is IERC721, IERC721Enumerable, ERC5058, Ownable {
    using Strings for uint256;

    string private _baseuri;
    uint256 public supply = 0;
    uint256 public constant max_supply = 10; 

    constructor(string memory name, string memory symbol) public ERC5058(name, symbol){}

    function setBaseURI(string memory _uri) public onlyOwner {
        _baseuri = _uri;
    }

    function mint() external {
        require(supply < max_supply, "minting has finished");
        super._safeMint(msg.sender, supply);
        supply++; 
    }

    function baseURI() public view returns (string memory) {
        return _baseuri;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);

        string memory base = baseURI();
        return bytes(base).length > 0 ? string(abi.encodePacked(base, tokenId.toString())) : "";
    }

    function _burn(uint256 tokenId) internal override {
        ERC5058._burn(tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override(IERC721, ERC5058){
        ERC5058.safeTransferFrom(from, to, tokenId, _data);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override(IERC721, ERC5058) {
        ERC5058.safeTransferFrom(from, to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override(IERC721, ERC5058){
        ERC5058.safeTransferFrom(from, to, tokenId);
    }
}