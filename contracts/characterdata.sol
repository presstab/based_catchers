import "@openzeppelin/contracts/access/Ownable.sol";

contract characterData is Ownable {

    struct Traits {
        uint8 strength;
        uint8 valor;
        uint8 intelligence;
        uint8 speed;
        uint8 magic;
    }

    // Nft unique hash (keccak(contract address, id)) => trait data
    mapping(uint256 => Traits) private mapData;

    function addData(uint256 _hash, uint8[5] calldata _data) public onlyOwner {
        mapData[_hash] = Traits(_data[0], _data[1], _data[2], _data[3], _data[4]);
    }

    function data(uint256 _hash) public view returns (uint8, uint8, uint8, uint8, uint8) {
        Traits memory d = mapData[_hash];
        if (d.strength == 0 && d.valor == 0 && d.intelligence == 0 && d.speed == 0 && d.magic == 0) {
            require(false, "err: no character data");
        }  
        return (d.strength, d.valor, d.intelligence, d.speed, d.magic);
    }
}