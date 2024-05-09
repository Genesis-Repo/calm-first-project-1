// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract NFTMarketplace is ERC721, Ownable, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    uint256 private _royaltyPercentage; // Royalty percentage for creators

    struct Item {
        uint256 id;
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        uint256 royaltyAmount; // Amount of royalty for creators
        bool sold;
    }

    mapping(uint256 => Item) private items;

    event ItemListed(uint256 indexed id, address indexed nftContract, uint256 indexed tokenId, uint256 price);
    event ItemSold(uint256 indexed id, address indexed buyer, uint256 price);
    event ItemRemoved(uint256 indexed id);

    constructor(string memory name_, string memory symbol_, uint256 royaltyPercentage) ERC721(name_, symbol_) {
        _royaltyPercentage = royaltyPercentage;
    }

    // Function to list an NFT item for sale
    function listNFT(address _nftContract, uint256 _tokenId, uint256 _price) external whenNotPaused {
        require(_price > 0, "Price must be greater than zero");
        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        Item memory newItem = Item(itemId, msg.sender, _nftContract, _tokenId, _price, 0, false);
        items[itemId] = newItem;

        emit ItemListed(itemId, _nftContract, _tokenId, _price);
    }

    // Function to buy an NFT item
    function buyNFT(uint256 _id) external payable whenNotPaused {
        Item storage item = items[_id];

        require(item.id > 0 && item.sold == false, "Item not available");
        require(msg.value >= item.price, "Insufficient funds");

        uint256 royaltyAmount = (item.price * _royaltyPercentage) / 100;
        item.royaltyAmount = royaltyAmount;

        item.sold = true;
        _itemsSold.increment();

        address payable seller = payable(item.seller);
        (bool success, ) = seller.call{value: item.price - royaltyAmount}("");
        require(success, "Transfer to seller failed");

        _transfer(seller, msg.sender, item.tokenId); // Transfer NFT to buyer

        if (royaltyAmount > 0) {
            address payable creator = payable(ownerOf(item.tokenId));
            (bool creatorSuccess, ) = creator.call{value: royaltyAmount}("");
            require(creatorSuccess, "Transfer to creator failed");
        }

        emit ItemSold(item.id, msg.sender, item.price);
    }

    // Function to get details of an NFT item
    function getItem(uint256 _id) external view returns (Item memory) {
        return items[_id];
    }

    // Function to remove an NFT item from sale
    function removeNFT(uint256 _id) external whenNotPaused {
        Item storage item = items[_id];
        require(item.id > 0 && item.seller == msg.sender, "Invalid item or not the seller");

        delete items[_id];

        emit ItemRemoved(_id);
    }

    // Function to set the royalty percentage
    function setRoyaltyPercentage(uint256 percentage) external onlyOwner {
        require(percentage <= 100, "Royalty percentage cannot exceed 100%");
        _royaltyPercentage = percentage;
    }

    // Function to pause the contract, preventing new listings and purchases
    function pause() external onlyOwner {
        _pause();
    }

    // Function to unpause the contract, allowing new listings and purchases
    function unpause() external onlyOwner {
        _unpause();
    }
}