import "@openzeppelin/contracts/access/Ownable.sol";
import "./ierc5058.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ICharacterData {
    function data(uint256 _hash) external view returns (uint8 strength, uint8 valor, uint8 intelligence, uint8 speed, uint8 magic);
}

struct Traits {
    uint8 strength;
    uint8 valor;
    uint8 intelligence;
    uint8 speed;
    uint8 magic;
}

contract Game is Ownable {
    //The base nft
    IERC721 public baseNft;

    uint16 public maxTeamSize;

    //list of nft's that can be attached to the base nft
    address[] public playableNft;

    //Contract that tracks on chain metadata for each character
    ICharacterData public characterData; 

    struct NftInstance {
        address addr; // the address of the nft contract
        uint256 id; // the id of the nft being used
    }

    struct Team {
        mapping(uint256 => NftInstance) members;
        uint256 length;
    }

    //team_id => Team
    mapping(uint256 => Team) public mapTeams; // team_id => Team

    //todo list of team_id

    //track teams owned by a user address
    mapping(address => uint256[]) public mapUserTeams; // user address => teamId[]

    //track what team an nft is on
    mapping(uint256 => uint256) public mapNftTeam; //nft hash (keccak(address,id)) => team_id

    constructor (address initialOwner, IERC721 _baseNft, uint16 _maxTeamSize) Ownable(initialOwner){
        baseNft = _baseNft;
        maxTeamSize = _maxTeamSize;
    }

    // Get the unique hash of a team
    // 8503 gas for 7 elements
    function getHash(NftInstance[] calldata _nftInstances) public pure returns(uint256){
        uint256 hash = 0;
        uint len = _nftInstances.length;
        for (uint16 i = 0; i < len; i++){
            NftInstance calldata instance = _nftInstances[i];
            hash = uint256(keccak256(abi.encode(hash, instance.addr, instance.id)));
        }
        return hash;
    }

    function getHash(NftInstance memory _nft) public pure returns(uint256){
        return uint256(keccak256(abi.encode(_nft.addr, _nft.id)));
    }

    function getUserTeams(address _user) public view returns (uint256[] memory){
        return mapUserTeams[_user];
    }

    /**
     * @notice Creates a new team of NFT's that are eligible to battle.
     * - All NFT's must be unlocked
     * - This will lock all of the team NFT's to this contract
     *
     * @param _team an array of NFT Instances that will form a team.
       The team must include one and only one baseNFT.
     */
    function createTeam(NftInstance[] calldata _team) public {
        require(_team.length <= maxTeamSize, "err: team is too large");

        uint256 len = _team.length;
        uint256 team_id = getHash(_team);
        Team storage team = mapTeams[team_id];
        team.length = len;

        for (uint256 i = 0; i < len; i++){
            NftInstance calldata nft = _team[i];

            //First team member must be the base
            if (i == 0){
                require(nft.addr == address(baseNft), "err: first team member must be base");
            }
            
            //The owner must be the msg sender
            require(IERC721(nft.addr).ownerOf(nft.id) == msg.sender, "err: msg.sender does not own nft");

            //Check if this is an approved nft
            if (i > 0){
                uint256 n = getSubNft(nft.addr);
                require(n < playableNft.length, "err: nft not valid for teams");
            }

            //Ensure metadata is functional
            //characterData.data(getHash(nft));

            //Lock each nft for an indefinite time
            IERC5058(nft.addr).lock(nft.id);

            //track nft's current team
            mapNftTeam[getHash(nft)] = team_id;

            team.members[i] = nft;
        }

        mapUserTeams[msg.sender].push(team_id);
    }

    /**
     * @notice Disband a team.
     * - All NFT's must be unlocked
     * - This will unlock all of the team NFT's from this contract
     *
     * @param _id the unique id of the team.
     */
    function disbandTeam(uint256 _id) public {
        Team storage team = mapTeams[_id];
        uint256 len = team.length;
        require(len > 0, "team does not exist");

        for (uint256 i = 0; i < len; i++){
            NftInstance memory nft = team.members[i];

            if (i == 0){
                //The owner must be the msg sender
                require(IERC721(nft.addr).ownerOf(nft.id) == msg.sender, "err: msg.sender does not own nft");
            }

            //Unlock nft
            IERC5058(nft.addr).unlock(nft.id);

            //Remove nft tracking
            delete mapNftTeam[getHash(nft)];

            //Remove from team
            delete team.members[i];
        }

        //Remove team from user tracking
        uint256[] storage userTeams = mapUserTeams[msg.sender];
        uint256 count = userTeams.length;
        for (uint256 i = 0; i < count; i++){
            if (userTeams[i] == _id) {
                //Move last element to this spot
                if (count > 1) {
                    userTeams[i] = userTeams[count - 1];
                }
                userTeams.pop();
                break;
            }
        }

        //Delete team from mapping
        delete mapTeams[_id];
    }

    function battle(uint256 _idAttacker, uint256 _idDefender) public view returns (uint256) {
        Team storage teamAttack = mapTeams[_idAttacker];
        Team storage teamDefend = mapTeams[_idDefender];
        require(teamAttack.length > 0, "err: team attack does not exist");
        require(teamDefend.length > 0, "err: team defend does not exist");

        //Attacker must be the owner of the team //todo: better on gas to store owner address in the team struct?
        require(IERC721(teamAttack.members[0].addr).ownerOf(teamAttack.members[0].id) == msg.sender, "err: msg.sender does not own nft");

        //Add up traits of each team
        uint8 lenAttack = uint8(teamAttack.length);
        Traits memory traitsAttack;
        for (uint8 i = 0; i < lenAttack; i++) {
            NftInstance memory nft = teamAttack.members[i];
            Traits memory traits;
            (traits.strength, traits.valor, traits.intelligence, traits.speed, traits.magic) = characterData.data(getHash(nft));
            traitsAttack.strength += traits.strength;
            traitsAttack.valor += traits.valor;
            traitsAttack.intelligence += traits.intelligence;
            traitsAttack.speed += traits.speed;
            traitsAttack.magic += traits.magic;
        }

        uint8 lenDefend = uint8(teamDefend.length);
        Traits memory traitsDefend;
        for (uint8 i = 0; i < lenDefend; i++) {
            NftInstance memory nft = teamDefend.members[i];
            Traits memory traits;
            (traits.strength, traits.valor, traits.intelligence, traits.speed, traits.magic) = characterData.data(getHash(nft));
            traitsDefend.strength += traits.strength;
            traitsDefend.valor += traits.valor;
            traitsDefend.intelligence += traits.intelligence;
            traitsDefend.speed += traits.speed;
            traitsDefend.magic += traits.magic;
        }

        //Modify traits of each team using random oracle


        //Use battle algorithm to determine winner
        uint64 scoreAttack = uint64(traitsAttack.strength) + uint64(traitsAttack.valor) + uint64(traitsAttack.intelligence) + uint64(traitsAttack.speed) + uint64(traitsAttack.magic);
        uint64 scoreDefend = uint64(traitsDefend.strength) + uint64(traitsDefend.valor) + uint64(traitsDefend.intelligence) + uint64(traitsDefend.speed) + uint64(traitsDefend.magic);
    
        if (scoreAttack > scoreDefend) {
            return _idAttacker;
        }

        return _idDefender;
    }

    //Get the subnft slot within attachableNft array
    function getSubNft(address _subNft) internal view returns (uint256) {
        //Identify which subNft is being used
        uint256 n = ~uint256(0);
        for (uint256 i = 0 ; i < playableNft.length; i++) {
            if (_subNft == playableNft[i]) {
                n = i;
                break;
            }
        }
        return n;
    }

    //Add a nft collection that is approved to be added to a team
    function addPlayableNft(IERC721 _subNft) public onlyOwner {
        //Double check that the nft is not already added
        for (uint256 i = 0; i < playableNft.length; i++) {
            require(playableNft[i] != address(_subNft), "subnft already exists!");
        }
        playableNft.push(address(_subNft));
    }

    //Set the maximum team size
    function setMaxTeamSize(uint16 _max) public onlyOwner {
        maxTeamSize = _max;
    }

    //Set the contract that tracks nft data
    function setCharacterData(address _characterData) public onlyOwner {
        characterData = ICharacterData(_characterData);
    }
}