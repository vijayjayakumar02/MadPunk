// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Madpunk is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    // store erc20 token address
    IERC20 public punkCoin;

    // store address of madpunk governance wallet
    address public governanceWallet;

    // convert tierMaxTotalAttributes, tierMaxSupply, tierPrice, storeLimitPerTier, tierRequirements to a single datatype
    struct TierInfo {
        uint8[5] tierMaxTotalAttributes;
        uint24[5] tierMaxSupply;
        uint96[5] tierPrice;
        uint16[5] storeLimitPerTier;
        uint16[5] tierRequirements;
    }

    TierInfo internal tierInfo;

    // total minted supply in each tier
    uint128[5] public totalMintedSupply;

    // total sold supply in each tier
    uint128[5] public totalSoldSupply;

    // Struct to store attributes of token (health, attack, defense, speed, evasion, magic)
    struct Attributes {
        uint8 health;
        uint8 attack;
        uint8 defense;
        uint8 speed;
        uint8 evasion;
        uint8 magic;
    }

    // struct to store the token Info
    struct ItemInfo {
        string name;
        uint8 tier; // tier 0 - common, tier 1 - uncommon, tier 2 - rare, tier 3 - mythical, tier 4 - legendary
        string item;
        string image;
        Attributes attributes; // attributes of token (health, attack, defense, speed, evasion, magic)
        uint8 category; // store category of token: 0 for Character, 1 for Skin, 2 for Weapon
    }

    // mapping to store token info
    mapping(uint256 => ItemInfo) public itemInfo;

    // struct to store avatar token info
    struct SaleInfo {
        uint256 price;
        uint8 currencyType; // store currency type: 0 for punkCoin, 1 for TRX
        bool sale;
        address creator;
        uint8[] condition; // store condition of token: i.e which listed token or tokens of creator is required to buy this token - only for item NFT.
    }

    // mapping to store tokenId -> sale info
    mapping(uint256 => SaleInfo) public saleInfo;

    constructor(address _punkCoin) ERC721("madpunk", "PUNK") {
        punkCoin = IERC20(_punkCoin);
        governanceWallet = msg.sender;

        // set tier info manually
        tierInfo = TierInfo(
            [16, 20, 24, 32, 40],
            [0, 1020000, 180000, 800, 12],
            [
                0,
                1000000000000000000,
                100000000000000000000,
                100000000000000000000000,
                10000000000000000000000000000
            ],
            [0, 4000, 800, 12, 1],
            [0, 12000, 2000, 200, 10]
        );
    }

    // function to check if token is item NFT or not
    function isItemNFT(uint256 _tokenId) public view returns (bool) {
        if (bytes(itemInfo[_tokenId].name).length > 0) {
            return true;
        } else {
            return false;
        }
    }

    // function to checkCondition
    function checkNewCondition(address sender, uint8[] memory _condition)
        internal
        view
    {
        require(
            _condition.length <= 6,
            "Condition length should be less than 6"
        );

        if (_condition.length > 0) {
            for (uint8 i = 0; i < _condition.length; i++) {
                require(
                    ownerOf(_condition[i]) == sender,
                    "All the condition tokens should be owned by the buyer"
                );
                require(
                    saleInfo[_condition[i]].sale == true,
                    "All the condition tokens should be listed for sale"
                );
                require(
                    saleInfo[_condition[i]].creator == sender,
                    "All the condition tokens should be owned by the creator"
                );

                // check if all the condition tokens are item NFTs
                require(
                    isItemNFT(_condition[i]) == true,
                    "All the condition tokens should be item NFTs"
                );
            }
        }
    }

    // function to mint NFT
    function mintItemNFT(
        string memory _name,
        uint8 _tier, // tier 0 - common, tier 1 - uncommon, tier 2 - rare, tier 3 - mythical, tier 4 - legendary
        string memory _item,
        string memory _image,
        uint8[6] memory _attributes, // attributes of token (health, attack, defense, speed, evasion, magic) passed as array
        uint256 _price,
        uint8 _currencyType,
        uint8 _category, // 0 for Character, 1 for Skin, 2 for Weapon
        bool _sale,
        uint8[] memory _condition
    ) public returns (uint256) {
        require(_tier < 5, "Invalid tier");
        require(_currencyType < 2, "Invalid currency type");
        require(_price > 0, "Price should be greater than 0");
        require(
            bytes(_name).length > 0 && bytes(_name).length < 50,
            "Invalid name"
        );
        require(bytes(_item).length > 0, "Invalid item");
        require(bytes(_image).length > 0, "Invalid image");
        require(_category < 3, "Invalid category");

        // check condition
        checkNewCondition(msg.sender, _condition);

        // check if all the attributes are less than or equal to tierMaxTotalAttributes
        uint8 totalAttributes = 0;
        for (uint8 i = 0; i < _attributes.length; i++) {
            totalAttributes += _attributes[i];
        }

        require(
            totalAttributes == tierInfo.tierMaxTotalAttributes[_tier],
            "Invalid attributes"
        );

        // if tier is !=0
        if (_tier != 0) {
            handleTier(msg.sender, _tier);
        }

        // increase totalMintedSupply
        totalMintedSupply[_tier] += 1;

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(msg.sender, tokenId);

        itemInfo[tokenId] = ItemInfo({
            name: _name,
            tier: _tier,
            item: _item,
            image: _image,
            attributes: Attributes(
                _attributes[0],
                _attributes[1],
                _attributes[2],
                _attributes[3],
                _attributes[4],
                _attributes[5]
            ),
            category: _category
        });

        saleInfo[tokenId] = SaleInfo({
            price: _price,
            currencyType: _currencyType,
            sale: _sale,
            creator: msg.sender,
            condition: _condition
        });

        return tokenId;
    }

    // function to handle tier upgrade
    function handleTier(address sender, uint8 _tier) internal {
        require(
            totalMintedSupply[_tier] < tierInfo.tierMaxSupply[_tier],
            "Tier max supply reached"
        );

        require(
            totalMintedSupply[_tier] < tierInfo.storeLimitPerTier[_tier],
            "Store limit per tier reached"
        );

        require(
            totalSoldSupply[_tier - 1] >= tierInfo.tierRequirements[_tier],
            "Creator has not sold enough tokens of previous tier"
        );

        require(
            punkCoin.balanceOf(msg.sender) >= tierInfo.tierPrice[_tier],
            "Creator has not enough punkCoin to mint token"
        );

        punkCoin.transferFrom(
            sender,
            governanceWallet,
            tierInfo.tierPrice[_tier]
        );
    }

    // function to mint avatar NFT
    function mintAvatarNFT(
        string memory _tokenURI,
        uint256 _price,
        uint8 _currencyType,
        bool _sale
    ) public returns (uint256) {
        require(_currencyType < 2, "Invalid currency type");
        require(_price > 0, "Price should be greater than 0");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(msg.sender, tokenId);

        _setTokenURI(tokenId, _tokenURI);

        saleInfo[tokenId] = SaleInfo({
            price: _price,
            currencyType: _currencyType,
            sale: _sale,
            creator: msg.sender,
            condition: new uint8[](0)
        });

        return tokenId;
    }

    // function to list NFTs for sale
    function listNFT(
        uint256 tokenId,
        uint256 _price,
        uint8 _currencyType,
        uint8[] memory _condition
    ) public {
        require(_exists(tokenId), "Token does not exist");
        require(saleInfo[tokenId].sale == false, "Token already listed");
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Only owner can list NFT for sale"
        );
        require(_price > 0, "Price should be greater than 0");
        require(_currencyType < 2, "Invalid currency type");

        changeCondition(msg.sender, tokenId, _condition);

        saleInfo[tokenId].price = _price;
        saleInfo[tokenId].currencyType = _currencyType;
        saleInfo[tokenId].sale = true;
    }

    // function to change condition of NFTs
    function changeCondition(
        address sender,
        uint256 tokenId,
        uint8[] memory _condition
    ) public {
        require(isItemNFT(tokenId) == true, "Token is not an item NFT");
        require(
            _isApprovedOrOwner(sender, tokenId),
            "Only owner can change condition"
        );
        require(
            saleInfo[tokenId].creator == sender,
            "Only creator can change condition"
        );

        // check condition
        checkNewCondition(sender, _condition);

        saleInfo[tokenId].condition = _condition;
    }

    // function to unlist a NFT
    function unlistNFT(uint256 tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Only owner can unlist NFT"
        );
        require(saleInfo[tokenId].sale == true, "Token not listed");
        saleInfo[tokenId].sale = false;
    }

    // function to buy a NFT
    function buyNFT(uint256 tokenId) public payable {
        require(ownerOf(tokenId) != msg.sender, "You can't buy your own NFT");
        require(saleInfo[tokenId].sale == true, "Token not listed");

        // check if buyer passess the condition of token
        if (saleInfo[tokenId].condition.length > 0) {
            for (uint8 i = 0; i < saleInfo[tokenId].condition.length; i++) {
                require(
                    ownerOf(saleInfo[tokenId].condition[i]) == msg.sender,
                    "You don't have required items"
                );
            }
        }

        address owner = ownerOf(tokenId);

        if (saleInfo[tokenId].currencyType == 0) {
            require(
                punkCoin.allowance(msg.sender, address(this)) >=
                    saleInfo[tokenId].price,
                "Insufficient Store Coin allowance"
            );

            // send 1% of the sale price to governance wallet
            punkCoin.transferFrom(
                msg.sender,
                governanceWallet,
                saleInfo[tokenId].price / 100
            );

            // send remaining amount to owner
            punkCoin.transferFrom(
                msg.sender,
                owner,
                saleInfo[tokenId].price - (saleInfo[tokenId].price / 100)
            );
        } else {
            require(
                msg.value >= saleInfo[tokenId].price,
                "Insufficient TRX balance"
            );

            // send 2% of the sale price to governance wallet
            payable(governanceWallet).transfer(msg.value / 50);

            // send remaining amount to owner
            payable(owner).transfer(msg.value - (msg.value / 50));
        }

        _safeTransfer(owner, msg.sender, tokenId, "");

        saleInfo[tokenId].sale = false;
        saleInfo[tokenId].condition = new uint8[](0);

        // update total sold supply
        if (isItemNFT(tokenId) == true) {
            totalSoldSupply[itemInfo[tokenId].tier] += 1;
        }
    }

    // function to get all NFTs for sale with category option
    // @params category (0-3) 0 for Character, 1 for Skin, 2 for Weapon, 3 - Avatar
    function getNFTsForSale(uint8 category)
        public
        view
        returns (string memory)
    {
        string memory result = "[";
        for (uint256 i = 0; i < totalSupply(); i++) {
            if (category == 3) {
                if (saleInfo[i].sale == true && isItemNFT(i) == false) {
                    result = string(
                        abi.encodePacked(
                            result,
                            getNFTBasicInfo(i),
                            ',"saleInfo":',
                            getSaleInfo(i),
                            "},"
                        )
                    );
                }
            } else {
                if (
                    saleInfo[i].sale == true &&
                    isItemNFT(i) == true &&
                    itemInfo[i].category == category
                ) {
                    result = string(
                        abi.encodePacked(
                            result,
                            getNFTBasicInfo(i),
                            ',"saleInfo":',
                            getSaleInfo(i),
                            "},"
                        )
                    );
                }
            }
        }
        result = string(abi.encodePacked(result, "]"));
        return result;
    }

    function getNFTInfoOfUser(address user, uint8 category)
        public
        view
        returns (string memory)
    {
        uint256 tokenCount = balanceOf(user);
        if (tokenCount == 0) {
            return "[]";
        }
        string memory result = "[";
        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(user, i);

            if (category == 3 && isItemNFT(tokenId) == false) {
                result = string(
                    abi.encodePacked(
                        result,
                        getNFTBasicInfo(i),
                        ',"saleInfo":',
                        getSaleInfo(i),
                        "},"
                    )
                );
            } else if (
                category != 3 &&
                isItemNFT(tokenId) == true &&
                itemInfo[tokenId].category == category
            ) {
                result = string(
                    abi.encodePacked(
                        result,
                        getNFTBasicInfo(i),
                        ',"saleInfo":',
                        getSaleInfo(i),
                        "},"
                    )
                );
            }
        }
        result = string(abi.encodePacked(result, "]"));
        return result;
    }

    function getSaleInfo(uint256 tokenId) public view returns (string memory) {
        string memory result = "{";
        result = string(
            abi.encodePacked(
                result,
                '"price":',
                Strings.toString(saleInfo[tokenId].price),
                ',"currencyType":',
                Strings.toString(saleInfo[tokenId].currencyType),
                ',"condition":['
            )
        );

        for (uint8 i = 0; i < saleInfo[tokenId].condition.length; i++) {
            result = string(
                abi.encodePacked(
                    result,
                    Strings.toString(saleInfo[tokenId].condition[i])
                )
            );
            if (i != saleInfo[tokenId].condition.length - 1) {
                result = string(abi.encodePacked(result, ","));
            }
        }

        result = string(abi.encodePacked(result, "]}"));
        return result;
    }

    // function to get usable details of NFT
    function getNFTBasicInfo(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        if (isItemNFT(tokenId) == true) {
            return
                string(
                    abi.encodePacked(
                        '{"name":"',
                        itemInfo[tokenId].name,
                        // send type as item
                        '","type":"item","item":"',
                        itemInfo[tokenId].item,
                        '", "category":"',
                        Strings.toString(itemInfo[tokenId].category),
                        '", "image":"',
                        itemInfo[tokenId].image,
                        '", "attributes": { "health": ',
                        Strings.toString(itemInfo[tokenId].attributes.health),
                        ', "attack": ',
                        Strings.toString(itemInfo[tokenId].attributes.attack),
                        ', "defence": ',
                        Strings.toString(itemInfo[tokenId].attributes.defense),
                        ', "speed": ',
                        Strings.toString(itemInfo[tokenId].attributes.speed),
                        ', "evasion": ',
                        Strings.toString(itemInfo[tokenId].attributes.evasion),
                        "}}"
                    )
                );
        } else {
            return
                string(
                    abi.encodePacked(
                        '{"type":"avatar", "tokenURI":"',
                        tokenURI(tokenId),
                        '"}'
                    )
                );
        }
    }

    // function to get all getNFTBasicInfo of a user
    // @params category (0-3) 0 for Character, 1 for Skin, 2 for Weapon, 3 - Avatar
    function getNFTBasicInfoOfUser(address user, uint8 category)
        public
        view
        returns (string memory)
    {
        uint256 tokenCount = balanceOf(user);
        if (tokenCount == 0) {
            return "[]";
        }
        string memory result = "[";
        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(user, i);

            if (category == 3 && isItemNFT(tokenId) == false) {
                result = string(
                    abi.encodePacked(result, getNFTBasicInfo(tokenId), ",")
                );
            } else if (
                category != 3 &&
                isItemNFT(tokenId) == true &&
                itemInfo[tokenId].category == category
            ) {
                result = string(
                    abi.encodePacked(result, getNFTBasicInfo(tokenId), ",")
                );
            }
        }
        result = string(abi.encodePacked(result, "]"));
        return result;
    }

    // function tokenURI
    // if itemInfo is empty, then it is avatar token so return tokenURI
    // else return itemInfo
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        if (isItemNFT(tokenId) == true) {
            return
                string(
                    abi.encodePacked(
                        "data:application/json;base64,",
                        Base64.encode(bytes(getNFTBasicInfo(tokenId)))
                    )
                );
        } else {
            return super.tokenURI(tokenId);
        }
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, 1);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}