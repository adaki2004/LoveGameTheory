// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";

contract LoveGameTheory is ERC1155, Ownable {

    struct MintPass {
        /// @dev Having able to set a price - in USDC (more readable to non-crypto ppl)
        uint256 passPrice;
        /// @dev To know how many in existence
        uint256 inCirculation;
        /// @dev MP revenue for artist
        uint256 artistRev;
        /// @dev Artist's claim address
        address artistAddress;
        /// @dev MagicContract
        address magicBurner;
        /// @dev Option to close a minting period for a specific MintPass type
        bool mintingClosed;
    }

    /// Different type of mint passes (0: Tier-1, 1: Tier-2, 2: Tier-2, etc.)
    mapping(uint256 => MintPass) public _mintPasses;
    uint256 public _currentMintPassIdCnt;

    event MintPassTypeAdded(
        uint256 mintPassId,
        uint256 mintPassPrice,
        bool mintingClosed
    );

    event MintPassPriceEdited(uint256 mintPassId, uint256 newPrice);
    event MintPassMintStatusEdited(uint256 mintPassId, bool mintingClosed);
    event MintPassMagicContractEdited(uint256 mintPassId, address magicContract);
    event MintPassArtistAddressEdited(uint256 mintPassId, address artistAddress);
    event MintPassMinted(uint256 index, address indexed user, uint256 amount);
    event MintPassBurnt(uint256 index, address indexed user, uint256 amount);

    /// @dev Contract name & symbol
    string public name = 'LoveGameTheory';
    string public symbol = 'LGT';
    // Mumbai:
    address public _currency = 0x11244ff7959d8E31A430a5D19F54912b67A0B209;
    //On mainnet:
    //address public _currency = 0xB22C05CeDbF879a661fcc566B5a759d005Cf7b4C;
    // Dead wallet
    address public _dead = 0x000000000000000000000000000000000000dEaD;

    // Non reentrancy lock
    bool internal locked;

    // Dev and LOVE treasury related
    uint256 _dev;
    address _devAdress = address(0);
    uint256 _loveTreasury;
    address _loveTreasuryAddress = address(0);

    /// @notice Check that a mint pass with given id exists
    /// @param id - Id of the mint pass
    modifier mpExists(uint256 id) {
        require(_mintPasses[id].passPrice != 0, 'Mint pass does not exists');
        _;
    }

    /// @notice Reentrancy guard
    modifier noReentrant() {
        require(!locked);
        locked = true;
        _;
        locked = false;
    }

    constructor(string memory baseUri) ERC1155(baseUri) {}

    /// @notice Add a mint pass type
    /// @param mintPassId - The id of the pass
    /// @param price - The price of the pass - can be 0 if backend has to sign something (like for SpaceCats which is a 'free' mint for coupon holders)
    /// @param mintingClosed - The status if the minting is closed (true) or not (false)
    function addMintPass(
        uint256 mintPassId,
        uint256 price,
        bool mintingClosed
    ) external onlyOwner {
        MintPass memory mp = MintPass(
            price,
            0,
            0,
            address(0),
            address(0),
            mintingClosed
        );
        
        _mintPasses[mintPassId] = mp;
        _currentMintPassIdCnt++;

        emit MintPassTypeAdded(
            mintPassId,
            price,
            mintingClosed
        );
    }

    /// @notice Mintpass' price editing
    /// @param mintPassId - The id of the pass
    /// @param newPrice - The new price
    function editPassPrice(uint256 mintPassId, uint256 newPrice)
        external
        onlyOwner
        mpExists(mintPassId)
    {
        MintPass memory mp = _mintPasses[mintPassId];

        /// @dev Modify the value and write back
        mp.passPrice = newPrice;
        _mintPasses[mintPassId] = mp;

        emit MintPassPriceEdited(mintPassId, newPrice);
    }

    /// @notice Mintpass' minting status parameter editing
    /// @param mintPassId - The id of the pass
    /// @param mintingClosed - Changing the minting status to closed (with true) or open (false)
    function editMintingClosed(uint256 mintPassId, bool mintingClosed)
        external
        onlyOwner
        mpExists(mintPassId)
    {
        MintPass memory mp = _mintPasses[mintPassId];

        /// @dev Modify the value and write back
        mp.mintingClosed = mintingClosed;
        _mintPasses[mintPassId] = mp;

        emit MintPassMintStatusEdited(mintPassId, mintingClosed);
    }

    /// @notice Mintpass' redeem contract setter
    /// @param mintPassId - The id of the pass
    /// @param magicBurner - Magic contract address which will be able to burn
    function editMagicContract(uint256 mintPassId, address magicBurner)
        external
        onlyOwner
        mpExists(mintPassId)
    {
        MintPass memory mp = _mintPasses[mintPassId];

        /// @dev Modify the value and write back
        mp.magicBurner = magicBurner;
        _mintPasses[mintPassId] = mp;

        emit MintPassMagicContractEdited(mintPassId, magicBurner);
    }

    /// @notice Mintpass' artists address setter
    /// @param mintPassId - The id of the pass
    /// @param artistAddress - Artist address which  the funds will be distributed
    function editArtistAddressContract(uint256 mintPassId, address artistAddress)
        external
        onlyOwner
        mpExists(mintPassId)
    {
        MintPass memory mp = _mintPasses[mintPassId];

        /// @dev Modify the value and write back
        mp.artistAddress = artistAddress;
        _mintPasses[mintPassId] = mp;

        emit MintPassArtistAddressEdited(mintPassId, artistAddress);
    }

    /// @notice Dev funds claiming - anoyone can claim but goes to dev anyways :)
    function claimDev()
        noReentrant
        external
    {
        if (_devAdress != address(0)) {
            CurrencyTransferLib.transferCurrency(_currency,  address(this), _devAdress, _dev);
            _dev = 0;
        }
    }

    /// @notice LOVE Treasury funds claiming - anoyone can claim but goes to treasury anyways :)
    function claimLoveTreasury()
        noReentrant
        external
    {
        if (_loveTreasuryAddress != address(0)) {
            CurrencyTransferLib.transferCurrency(_currency,  address(this), _loveTreasuryAddress, _loveTreasury);
            _loveTreasury = 0;
        }
    }

    /// @notice Aritst funds claiming - anoyone can claim but goes to artist anyways :)
    function claimArtist(uint256 mintPassId)
        external
        noReentrant
        mpExists(mintPassId)
    {
        MintPass memory mp = _mintPasses[mintPassId];

        if (mp.artistAddress != address(0)) {
            CurrencyTransferLib.transferCurrency(_currency,  address(this), mp.artistAddress, mp.artistRev);
            _mintPasses[mintPassId].artistRev = 0;
        }
    }

    /// @notice This function mints the passes to the user
    /// @param mintPassId - The id of the pass
    /// @param amount - Amount to be minted for the user
    function mint(
        uint256 mintPassId,
        uint256 amount
    ) external payable mpExists(mintPassId) {
        // Minting is not closed
        require(
            !_mintPasses[mintPassId].mintingClosed,
            'Minting is closed currently'
        );
        
        uint256 totalPrice = amount * _mintPasses[mintPassId].passPrice;
        // Burn one third of the LOVE revenue
        uint256 one_third_amount = (totalPrice * 3300) / 10000;

        // 33% to artist and his/her community 
        _mintPasses[mintPassId].artistRev += one_third_amount;

        // Rest of 33% is for dev + LOVE Treasury
        _loveTreasury += one_third_amount/2;
        _dev += one_third_amount/2;

        uint256 storeAtContract = totalPrice - one_third_amount;

        // Burn 33% of LOVE
        CurrencyTransferLib.transferCurrency(_currency, msg.sender, _dead, one_third_amount);
        // Store rest in contract until claimed
        CurrencyTransferLib.transferCurrency(_currency, msg.sender, address(this), storeAtContract);

        _mint(msg.sender, mintPassId, amount, '');

        _mintPasses[mintPassId].inCirculation += amount;
        
        emit MintPassMinted(mintPassId, msg.sender, amount);
    }

    /// @notice Burns and redeems via a magic contract
    /// @param mintPassId - The id of the pass
    /// @param amount - Amount to be minted for the user
    function burnAndRedeem(
        uint256 mintPassId,
        uint256 amount
    ) external payable mpExists(mintPassId) returns (uint256) {
        require(
            _mintPasses[mintPassId].magicBurner == msg.sender,
            'Burn and mint only from burner contract'
        );
        
        address burnAndRedeemInitiator = tx.origin;

        require(
            balanceOf(burnAndRedeemInitiator, mintPassId) >= amount,
            'Dont have that much amount'
        );

        _burn(burnAndRedeemInitiator, mintPassId, amount);

        _mintPasses[mintPassId].inCirculation -= amount;

        emit MintPassBurnt(mintPassId, msg.sender, amount);

        return amount;
    }

    /** GETTERS */

    /// @notice Returns the circulation count (including the ones which are burnt already)
    /// @param mintPassId - The id of the pass
    /// @return uint256 - The number of mints
    function getCirculationCount(uint256 mintPassId) external view mpExists(mintPassId) returns (uint256) {
        return _mintPasses[mintPassId].inCirculation;
    }

    /// @notice Returns a mint pass data
    /// @param mintPassId - The id of the pass
    /// @return mintPass - MintPass data
    function getMintPass(uint256 mintPassId)
        external
        view
        mpExists(mintPassId)
        returns (MintPass memory)
    {
        return _mintPasses[mintPassId];
    }

    /** SETTERS */

    /// @notice Set the dev revenue recipient
    /// @param newRecipient Address to set as new recipient
    function setDevAddress(address newRecipient) external onlyOwner {
        _devAdress = newRecipient;
    }

    /// @notice Set the treasury revenue recipient
    /// @param newRecipient Address to set as new recipient
    function setLoveTreasuryAddress(address newRecipient) external onlyOwner {
        _loveTreasuryAddress = newRecipient;
    }

    /// @notice Set the new currency
    /// @param newCurrency Address to set as new recipient
    function setCurrency(address newCurrency) external onlyOwner {
        _currency = newCurrency;
    }

    /// @notice Set the contract base URI
    /// @param newURI - The uri to be used
    function setContractURI(string memory newURI) external onlyOwner {
        _setURI(newURI);
    }
}
