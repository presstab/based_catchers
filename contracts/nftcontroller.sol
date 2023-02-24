import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 {
    /**
     * @dev Emitted when `tokenId` token is transfered from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
      * @dev Safely transfers `tokenId` token from `from` to `to`.
      *
      * Requirements:
      *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
      * - `tokenId` token must exist and be owned by `from`.
      * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
      * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
      *
      * Emits a {Transfer} event.
      */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

contract NftTracker is Ownable {
    //The base nft
    IERC721 public baseNft;

    uint16 public maxAttachments;

    //list of nft's that can be attached to the base nft
    address[] public attachableNft;

    struct NftInstance {
        address addr;
        uint256 id;
    }

    //Track nft attachments to the base Nft
    mapping(uint256 => NftInstance[]) public mapAttachments;

    constructor (IERC721 _baseNft) {
        baseNft = _baseNft;
    }

    function getTeam(uint256 _baseId) external view returns (NftInstance[] memory) {
        return mapAttachments[_baseId];
    }

    //Get the subnft slot within attachableNft array
    function getSubNft(IERC721 _subNft) internal view returns (uint256) {
        //Identify which subNft is being used
        uint256 n = ~uint256(0);
        for (uint256 i = 0 ; i < attachableNft.length; i++) {
            if (address(_subNft) == attachableNft[i]) {
                n = i;
                break;
            }
        }
        return n;
    }

    //attach a subNft to the baseNft
    function attach(uint256 _tokenIdBase, uint256 _tokenIdSub, IERC721 _subNft) public {
        uint256 n = getSubNft(_subNft);
        require(n < attachableNft.length, "invalid subNFT");
        require(msg.sender == baseNft.ownerOf(_tokenIdBase), "not owner of nft base id");
        require(msg.sender == _subNft.ownerOf(_tokenIdSub), "not owner of subnft id");

        //todo: Check that the subnft is not already attached
        // maybe need a tracked list of what nft's are actively attached?

        //Check total count of attachments
        require(mapAttachments[_tokenIdBase].length < maxAttachments);

        //Attach
        mapAttachments[_tokenIdBase].push(NftInstance(address(_subNft), _tokenIdSub));
    }

    //Find the index of the subnft that is attached
    function getSubIndex(uint256 _tokenIdBase, address _subNft, uint256 _tokenIdSub) internal view returns (uint256) {
        for (uint256 i = 0; i < mapAttachments[_tokenIdBase].length; i++) {
            if (mapAttachments[_tokenIdBase][i].addr == _subNft && mapAttachments[_tokenIdBase][i].id == _tokenIdSub) {
                return i;
            }
        }
        require(false, "getSubIndex: could not find subnft");
        return 0;
    }

    //Detach sub nft from base nft
    function detach(uint256 _tokenIdBase, IERC721 _subNft, uint256 _tokenIdSub) public {
        uint256 n = getSubNft(_subNft);
        require(n < attachableNft.length, "invalid subNFT");
        require(msg.sender == baseNft.ownerOf(_tokenIdBase), "not owner of nft base id");

        uint256 index = getSubIndex(_tokenIdBase, address(_subNft), _tokenIdSub);

        // Move the last element to the deleted spot.
        // Remove the last element.
        mapAttachments[_tokenIdBase][index] = mapAttachments[_tokenIdBase][mapAttachments[_tokenIdBase].length-1];
        mapAttachments[_tokenIdBase].pop();
    }

    //Detach all sub nft from a base nft
    function detachAll(uint256 _tokenIdBase) public {
        require(msg.sender == baseNft.ownerOf(_tokenIdBase), "not owner of nft base id");
        delete mapAttachments[_tokenIdBase];
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