import "@openzeppelin/contracts/access/Ownable.sol";
import "./erc5058.sol";

contract nft is ERC5058, Ownable {
    //using Strings for uint256;

    string private _baseuri;
    uint256 public supply = 0;
    uint256 public constant max_supply = 10; 

    constructor(string memory name, string memory symbol) ERC5058(name, symbol) Ownable(address(msg.sender)){}

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
        require(_ownerOf(tokenId) != address(0), "token not yet minted");

        string memory base = baseURI();
        return bytes(base).length > 0 ? string(abi.encodePacked(base, tokenId)) : "";
    }

    //todo add checks for permission to burn!
    // function _burn(uint256 tokenId) internal override {
    //     ERC5058.burn(tokenId);
    // }
}