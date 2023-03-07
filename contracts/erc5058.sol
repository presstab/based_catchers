import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

// SPDX-License-Identifier: CC0-1.0

/**
 * @dev EIP-721 Non-Fungible Token Standard, optional lockable extension
 * ERC721 Token that can be locked for a certain period and cannot be transferred.
 * This is designed for a non-escrow staking contract that comes later to lock a user's NFT
 * while still letting them keep it in their wallet.
 * This extension can ensure the security of user tokens during the staking period.
 * If the nft lending protocol is compatible with this extension, the trouble caused by the NFT
 * airdrop can be avoided, because the airdrop is still in the user's wallet
 */
interface IERC5058 {
    /**
     * @dev Emitted when `tokenId` token is locked by `operator` from `from`.
     */
    event Locked(address indexed operator, address indexed from, uint256 indexed tokenId);

    /**
     * @dev Emitted when `tokenId` token is unlocked by `operator` from `from`.
     */
    event Unlocked(address indexed operator, address indexed from, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to lock the `tokenId` token.
     */
    event LockApproval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to lock all of its tokens.
     */
    event LockApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the locker who is locking the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function lockerOf(uint256 tokenId) external view returns (address locker);

    /**
     * @dev Lock `tokenId` token until the block number is greater than `expired` to be unlocked.
     *
     * Requirements:
     *
     * - `tokenId` token must be owned by `owner`.
     * - If the caller is not `owner`, it must be approved to lock this token
     * by either {lockApprove} or {setLockApprovalForAll}.
     *
     * Emits a {Locked} event.
     */
    function lock(uint256 tokenId) external;

    /**
     * @dev Unlock `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` token must be owned by `owner`.
     * - the caller must be the operator who locks the token by {lock}
     *
     * Emits a {Unlocked} event.
     */
    function unlock(uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to lock `tokenId` token.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved lock operator.
     * - `tokenId` must exist.
     *
     * Emits an {LockApproval} event.
     */
    function lockApprove(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an lock operator for the caller.
     * Operators can call {lock} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {LockApprovalForAll} event.
     */
    function setLockApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account lock approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getLockApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to lock all of the assets of `owner`.
     *
     * See {setLockApprovalForAll}
     */
    function isLockApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Returns if the `tokenId` token is locked.
     */
    function isLocked(uint256 tokenId) external view returns (bool);

    /**
     * @dev Returns the `tokenId` token lock expired time.
     */
    //function lockExpiredTime(uint256 tokenId) external view returns (uint256);
}

contract ERC5058 is IERC5058, ERC721Enumerable {

    //todo make sure others cant lock you to a contract that you approved

    constructor(string memory name, string memory symbol) public ERC721(name, symbol) {
    }

    mapping(uint256 => address) public mapLocks; // token id => locker address
    mapping(uint256 => address) private mapLockApprovals; // token id => address
    mapping(address => mapping(address => bool)) private mapLockApproveAll; // owner => (operator => true/false)

    function _isLocked(uint256 tokenId) internal view returns (bool){
        return mapLocks[tokenId] != address(0);
    }
    
    function transferFrom(address from, address to, uint256 tokenId) public override (ERC721, IERC721) virtual {
        require(!_isLocked(tokenId), "tokenId is locked");
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override (ERC721, IERC721) virtual {
        require(!_isLocked(tokenId), "tokenId is locked");
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override (ERC721, IERC721) virtual {
        require(!_isLocked(tokenId), "tokenId is locked");
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function _burn(uint256 tokenId) internal override virtual {
        require(!_isLocked(tokenId), "tokenId is locked");
        super._burn(tokenId);
    }

    /**
    * @dev Returns the locker who is locking the `tokenId` token.
    *
    * Requirements:
    *
    * - `tokenId` must exist.
    */
    function lockerOf(uint256 tokenId) external override view returns (address locker){
        require(!_isLocked(tokenId), "lock does not exist");
        return mapLocks[tokenId];
    }

    /**
    * @dev Lock `tokenId` token until the block number is greater than `expired` to be unlocked.
    *
    * Requirements:
    *
    * - `tokenId` token must be owned by `owner`.
    * - If the caller is not `owner`, it must be approved to lock this token
    * by either {lockApprove} or {setLockApprovalForAll}.
    *
    * Emits a {Locked} event.
    */
    function lock(uint256 tokenId) external override {
        // will fail if invalid tokenId
        address owner = ownerOf(tokenId);
        require(!_isLocked(tokenId), "Token already locked");

        //Check that caller is approved to lock
        if (owner != msg.sender) {
            // Operator can have approval to operate all id's belonging to an owner
            if (!_isLockApprovedForAll(owner, msg.sender)) {
                // Operator can by the unique lock operator for the specific tokenid
                require(_getLockApproved(tokenId) == msg.sender, "msg.sender is not approved to operate locks");
            }
        }

        mapLocks[tokenId] = msg.sender;
        emit Locked(msg.sender, msg.sender, tokenId);
    }

    /**
     * @dev Unlock `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` token must be owned by `owner`.
     * - the caller must be the operator who locks the token by {lock}
     *
     * Emits a {Unlocked} event.
     */
    function unlock(uint256 tokenId) external override {
        require(mapLocks[tokenId] == msg.sender, "msg.sender is not the locker");
        delete mapLocks[tokenId];
        emit Unlocked(msg.sender, msg.sender, tokenId);
    }

    /**
     * @dev Gives permission to `to` to lock `tokenId` token.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved lock operator.
     * - `tokenId` must exist.
     * - `tokenId` must be unlocked.
     *
     * Emits an {LockApproval} event.
     */
    function lockApprove(address to, uint256 tokenId) external override {
        require(ownerOf(tokenId) == msg.sender, "cannot approve lock unless tokenid owner");
        require(!_isLocked(tokenId), "cannot change lock approvals while tokenId is locked");
        
        mapLockApprovals[tokenId] = to;
        emit LockApproval(msg.sender, msg.sender, tokenId);
    }

    /**
     * @dev Approve or remove `operator` as an lock operator for the caller.
     * Operators can call {lock} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {LockApprovalForAll} event.
     */
    function setLockApprovalForAll(address operator, bool approved) external override {
        require(operator != msg.sender, "operator cannot be called");
        mapLockApproveAll[msg.sender][operator] = approved;
        emit LockApprovalForAll(msg.sender, operator, approved);
    }

    function _getLockApproved(uint256 tokenId) internal view returns (address operator) {
        require(_exists(tokenId), "tokenId does not exist");
        return mapLockApprovals[tokenId];
    }

    /**
     * @dev Returns the account lock approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getLockApproved(uint256 tokenId) external override view returns (address operator) {
        return _getLockApproved(tokenId);
    }

    function _isLockApprovedForAll(address owner, address operator) internal view returns (bool) {
        return mapLockApproveAll[owner][operator];
    }

    /**
     * @dev Returns if the `operator` is allowed to lock all of the assets of `owner`.
     *
     * See {setLockApprovalForAll}
     */
    function isLockApprovedForAll(address owner, address operator) external override view returns (bool) {
        return _isLockApprovedForAll(owner, operator);
    }

    /**
     * @dev Returns if the `tokenId` token is locked.
     */
    function isLocked(uint256 tokenId) external override view returns (bool){
        return _isLocked(tokenId);
    }

    /**
     * @dev Returns the `tokenId` token lock expired time.
     */
    // function lockExpiredTime(uint256 tokenId) external override view returns (uint256){
    //     return mapLocks[tokenId].heightUnlock;
    // }

}