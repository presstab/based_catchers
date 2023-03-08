import "@openzeppelin/contracts/access/Ownable.sol";

enum Traits {
    Strength,
    Valor,
    Intelligence,
    Speed,
    Magic
}

uint64 constant MAX = ~uint64(0);
uint64 constant MASK_STRENGTH = ~(MAX>>8);
uint64 constant MASK_VALOR = ~(MAX>>16);
uint64 constant MASK_INTELLIGENCE = ~(MAX>>24);
uint64 constant MASK_SPEED = ~(MAX>>32);
uint64 constant MASK_MAGIC = ~(MAX>>40);

contract characterData is Ownable {

    // Nft unique hash (keccak(contract address, id)) => trait data
    mapping(uint256 => uint64) private mapData;

    function getMask(Traits _trait) private pure returns (uint64) {
        if (_trait == Traits.Strength) {
            return MASK_STRENGTH;
        } else if (_trait == Traits.Valor) {
            return MASK_VALOR;
        } else if (_trait == Traits.Intelligence) {
            return MASK_INTELLIGENCE;
        } else if (_trait == Traits.Speed) {
            return MASK_SPEED;
        } else if (_trait == Traits.Magic) {
            return MASK_MAGIC;
        }
        require(false, "err: invalid trait");
        return 0;
    }

    function getShift(Traits _trait) private pure returns (uint8) {
        if (_trait == Traits.Strength) {
            return 56;
        } else if (_trait == Traits.Valor) {
            return 48;
        } else if (_trait == Traits.Intelligence) {
            return 40;
        } else if (_trait == Traits.Speed) {
            return 32;
        } else if (_trait == Traits.Magic) {
            return 24;
        }
        require(false, "err: invalid trait");
        return 0;
    }

    function extractBits(uint64 _data, Traits _trait) private pure returns (uint8) {
        return uint8((_data & getMask(_trait)) >> getShift(_trait));
    }

    function addData(uint256 _hash, uint8[5] calldata _data) public onlyOwner returns (uint64) {
        uint64 d = 0;
        d = d|(uint64(_data[0])<<56);
        d = d|(uint64(_data[1])<<48);
        d = d|(uint64(_data[2])<<40);
        d = d|(uint64(_data[3])<<32);
        d = d|(uint64(_data[4])<<24);
        mapData[_hash] = d;
        return d;
    }

    function dataSingle(uint256 _hash, Traits _trait) public view returns (uint8) {
        uint64 d = (mapData[_hash] & getMask(_trait)) >> getShift(_trait);
        return uint8(d);
    }

    function data(uint256 _hash) public view returns (uint8, uint8, uint8, uint8, uint8) {
        uint64 d = mapData[_hash];
        require(d > 0, "err: no character data");
        return (extractBits(d, Traits(0)), extractBits(d, Traits(1)), extractBits(d, Traits(2)), extractBits(d, Traits(3)), extractBits(d, Traits(4)));
    }
}