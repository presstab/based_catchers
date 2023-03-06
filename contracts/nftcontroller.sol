import "@openzeppelin/contracts/access/Ownable.sol";
import "./ierc5058.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NftTracker is Ownable {
    //The base nft
    IERC721 public baseNft;

    uint16 public maxTeamSize = 7;

    //list of nft's that can be attached to the base nft
    address[] public attachableNft;

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

    constructor (IERC721 _baseNft) {
        baseNft = _baseNft;
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
                require(n < attachableNft.length, "err: nft not valid for teams");
            }

            //Lock each nft for an indefinite time
            IERC5058(nft.addr).lock(nft.id, 99999999999999);

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
                userTeams.pop(); //todo test this
                break;
            }
        }

        //Delete team from mapping
        delete mapTeams[_id];
    }

    //Get the subnft slot within attachableNft array
    function getSubNft(address _subNft) internal view returns (uint256) {
        //Identify which subNft is being used
        uint256 n = ~uint256(0);
        for (uint256 i = 0 ; i < attachableNft.length; i++) {
            if (_subNft == attachableNft[i]) {
                n = i;
                break;
            }
        }
        return n;
    }

    //Add a new attachable nft
    function addAttachableNft(IERC721 _subNft) public onlyOwner {
        //Double check that the subnft is not already added
        for (uint256 i = 0; i < attachableNft.length; i++) {
            require(attachableNft[i] != address(_subNft), "subnft already exists!");
        }
        attachableNft.push(address(_subNft));
    }
}