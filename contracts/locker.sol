import "./ierc5058.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface mintableIERC20 is IERC20 {
    function mint(address _to, uint256 _amount) external;
}


//todo reentrancy guard, safeerc20
contract locker is Ownable {
    // The reward token!
    mintableIERC20 public coin;
    // Dev address.
    address public devaddr;
    // Tokens created per block.
    uint256 public coinsPerBlock;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when staking starts.
    uint256 public startBlock;

    constructor(mintableIERC20 _coin, address _dev, uint256 _coinsPerBlock, uint256 _startBlock) public {
        coin = _coin;
        devaddr = _dev;
        coinsPerBlock = _coinsPerBlock;
        startBlock = _startBlock;
    }

    // Info of each user.
    struct NftInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of coins
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCoinsPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCoinsPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        address nft;           // Address of NFT contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. Coins to distribute per block.
        uint256 lastRewardBlock;  // Last block number that Coins distribution occurs.
        uint256 accCoinsPerShare;   // Accumulated Coins per share, times 1e12. See below.
        uint256 count; // The number of NFT's locked by this pool
    }

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each nft that stakes.
    mapping(uint256 => mapping(uint256 => NftInfo)) public nftInfo; // poolId => (nftId => info)

    // Add a new nft to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, address _nftToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        //poolExistence[_lpToken] = true;
        poolInfo.push(PoolInfo({
        nft : _nftToken,
        allocPoint : _allocPoint,
        lastRewardBlock : lastRewardBlock,
        accCoinsPerShare : 0,
        count : 0
        }));
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.count == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 blocks = block.number - pool.lastRewardBlock;
        uint256 coinReward = (blocks * coinsPerBlock * pool.allocPoint) / totalAllocPoint;
        //coin.mint(devaddr, coinReward / 10);
        coin.mint(address(this), coinReward);
        pool.accCoinsPerShare = pool.accCoinsPerShare + (coinReward * 1e12 / pool.count);
        pool.lastRewardBlock = block.number;
    }

    // Safe coin transfer function, just in case if rounding error causes pool to not have enough coins.
    function safeCoinTransfer(address _to, uint256 _amount) internal {
        uint256 coinBal = coin.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > coinBal) {
            transferSuccess = coin.transfer(_to, coinBal);
        } else {
            transferSuccess = coin.transfer(_to, _amount);
        }
        require(transferSuccess, "safeCoinTransfer: transfer failed");
    }

    //Lock nft to a staking pool
    function stake(uint256 tokenId, uint256 poolId) external {
        PoolInfo storage pool = poolInfo[poolId];
        NftInfo storage user = nftInfo[poolId][tokenId];
        IERC5058 nftToken = IERC5058(pool.nft);
        require(msg.sender == IERC721(pool.nft).ownerOf(tokenId), "msg.sender does not own tokenId");

        updatePool(poolId);
        pool.count = pool.count + 1;

        //Locking the nft will fail if tx.origin is not the owner
        nftToken.lock(tokenId, 999999999999999999);
        user.rewardDebt = pool.accCoinsPerShare / 1e12;
        user.amount = 1;
    }

    //Unstake/unlock
    function unstake(uint256 tokenId, uint256 poolId) external {
        PoolInfo storage pool = poolInfo[poolId];
        NftInfo storage user = nftInfo[poolId][tokenId];
        IERC5058 nftToken = IERC5058(pool.nft);
        require(msg.sender == IERC721(pool.nft).ownerOf(tokenId), "msg.sender does not own tokenId");
        require(user.amount == 1, "tokenId does not belong to staking pool");

        updatePool(poolId);
        pool.count = pool.count - 1;
        
        uint256 pending = (pool.accCoinsPerShare/1e12) - user.rewardDebt;
        if (pending > 0) {
            safeCoinTransfer(msg.sender, pending);
        }

        //Unlock nft token to unstake from contract
        nftToken.unlock(tokenId);
        
        //Remove nft tracking from the pool
        //todo - check the reward debt after removing, ensure that deletion occurs. Solidity and map deletion is strange.
        delete nftInfo[poolId][tokenId];
        //user.rewardDebt = pool.accCoinsPerShare/1e12;
        //emit Withdraw(msg.sender, _pid, _amount);
    }

    function harvestRewards(uint256 tokenId, uint256 poolId) external {
        PoolInfo storage pool = poolInfo[poolId];
        NftInfo storage user = nftInfo[poolId][tokenId];
        IERC5058 nftToken = IERC5058(pool.nft);
        require(msg.sender == IERC721(pool.nft).ownerOf(tokenId), "msg.sender does not own tokenId");
        require(nftToken.lockerOf(tokenId) == address(this), "tokenId is not locked to the staking contract");
        require(user.amount == 1, "tokenId does not belong to staking pool");

        updatePool(poolId);
        
        uint256 pending = (pool.accCoinsPerShare/1e12) - user.rewardDebt;
        if (pending > 0) {
            safeCoinTransfer(msg.sender, pending);
        }
        user.rewardDebt = pool.accCoinsPerShare/1e12;   
    }

    // View function to see pending coins on frontend.
    function pendingCoins(uint256 _pid, uint256 _tokenId) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        NftInfo storage user = nftInfo[_pid][_tokenId];
        uint256 accCoinsPerShare = pool.accCoinsPerShare;

        if (block.number > pool.lastRewardBlock && pool.count != 0) {
            uint256 blocks = block.number - pool.lastRewardBlock;
            uint256 coinReward = (blocks * coinsPerBlock * pool.allocPoint) / totalAllocPoint;
            accCoinsPerShare = accCoinsPerShare + (coinReward * 1e12 / pool.count);
        }
        return (accCoinsPerShare / 1e12) - user.rewardDebt;
    }

    function setEmissionRate(uint256 _coinsPerBlock) public onlyOwner {
        coinsPerBlock = _coinsPerBlock;
    }
}