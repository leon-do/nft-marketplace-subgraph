// SPDX-License-Identifier: GPL-3.0
pragma solidity >0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Marketplace is ReentrancyGuard, ERC1155Holder {
  // https://dev.to/dabit3/building-scalable-full-stack-apps-on-ethereum-with-polygon-2cfb
  using Counters for Counters.Counter;
  Counters.Counter private _itemIds;
  Counters.Counter private _itemsSold;

  address payable owner;

  constructor() {
    owner = payable(msg.sender);
  }

  struct MarketItem {
    uint itemId;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool sold;
  }

  mapping(uint256 => MarketItem) private idToMarketItem;

  event MarketItemCreated (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold
  );

  /* Places an item for sale on the marketplace */
  function sell721(
    address nftContract,
    uint256 tokenId,
    uint256 price
  ) public payable nonReentrant {
    require(price > 0, "Price must be at least 1 wei");

    _itemIds.increment();
    uint256 itemId = _itemIds.current();

    idToMarketItem[itemId] =  MarketItem(
      itemId,
      nftContract,
      tokenId,
      payable(msg.sender),
      payable(address(0)),
      price,
      false
    );

    IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

    emit MarketItemCreated(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      false
    );
  }

    /* Places an item for sale on the marketplace */
  function sell1155(
    address _nftContract,
    uint256 _tokenId,
    uint256 _price
  ) public payable nonReentrant {
    require(_price > 0, "Price must be at least 1 wei");

    _itemIds.increment();
    uint256 itemId = _itemIds.current();

    idToMarketItem[itemId] =  MarketItem(
      itemId,
      _nftContract,
      _tokenId,
      payable(msg.sender),
      payable(address(0)),
      _price,
      false
    );

    IERC1155(_nftContract).safeTransferFrom(msg.sender, address(this), _tokenId, 1, "");

    emit MarketItemCreated(
      itemId,
      _nftContract,
      _tokenId,
      msg.sender,
      address(0),
      _price,
      false
    );
  }

  /* Creates the sale of a marketplace item */
  /* Transfers ownership of the item, as well as funds between parties */
  function buy721(
    address _nftContract,
    uint256 _itemId
    ) public payable nonReentrant {
    uint price = idToMarketItem[_itemId].price;
    uint tokenId = idToMarketItem[_itemId].tokenId;
    require(msg.value == price, "Please submit the asking price in order to complete the purchase");

    idToMarketItem[_itemId].seller.transfer(msg.value);
    IERC721(_nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
    idToMarketItem[_itemId].owner = payable(msg.sender);
    idToMarketItem[_itemId].sold = true;
    _itemsSold.increment();

    emit MarketItemCreated(
      _itemId,
      _nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      false
    );
  }

  /* Creates the sale of a marketplace item */
  /* Transfers ownership of the item, as well as funds between parties */
  function buy1155(
    address _nftContract,
    uint256 _itemId
    ) public payable nonReentrant {
    uint price = idToMarketItem[_itemId].price;
    uint tokenId = idToMarketItem[_itemId].tokenId;
    require(msg.value == price, "Please submit the asking price in order to complete the purchase");

    idToMarketItem[_itemId].seller.transfer(msg.value);
    IERC1155(_nftContract).safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
    idToMarketItem[_itemId].owner = payable(msg.sender);
    idToMarketItem[_itemId].sold = true;
    _itemsSold.increment();

    emit MarketItemCreated(
      _itemId,
      _nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      true
    );
  }

  /* Sends NFT back to seller */
  function cancel721(
    address _nftContract, 
    uint256 _itemId
    ) public nonReentrant {
    uint tokenId = idToMarketItem[_itemId].tokenId;
    require(msg.sender == idToMarketItem[_itemId].seller, "Only seller can cancel");
    require(_nftContract == idToMarketItem[_itemId].nftContract, "Seller does not own token");
    IERC721(_nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
    idToMarketItem[_itemId].owner = payable(msg.sender);
    idToMarketItem[_itemId].sold = true;
    _itemsSold.increment();

    emit MarketItemCreated(
      _itemId,
      _nftContract,
      tokenId,
      msg.sender,
      address(0),
      idToMarketItem[_itemId].price,
      true
    );
  }

  /* Sends NFT back to seller */
  function cancel1155(
    address _nftContract, 
    uint256 _itemId
    ) public nonReentrant {
    uint tokenId = idToMarketItem[_itemId].tokenId;
    require(msg.sender == idToMarketItem[_itemId].seller, "Only seller can cancel");
    require(_nftContract == idToMarketItem[_itemId].nftContract, "Seller does not own token");
    IERC1155(_nftContract).safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
    idToMarketItem[_itemId].owner = payable(msg.sender);
    idToMarketItem[_itemId].sold = true;
    _itemsSold.increment();

    emit MarketItemCreated(
      _itemId,
      _nftContract,
      tokenId,
      msg.sender,
      address(0),
      idToMarketItem[_itemId].price,
      true
    );
  }

  /* Returns unsold market items from given contract & tokenId */
  function fetchMarketItems(
    address _nftContract,
    uint256 _tokenId
  ) public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == address(0) && idToMarketItem[i + 1].nftContract == _nftContract && idToMarketItem[i + 1].tokenId == _tokenId) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == address(0) && idToMarketItem[i + 1].nftContract == _nftContract && idToMarketItem[i + 1].tokenId == _tokenId) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns all unsold market items */
  function fetchAllMarketItems() public view returns (MarketItem[] memory) {
    uint itemCount = _itemIds.current();
    uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
    uint currentIndex = 0;

    MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    for (uint i = 0; i < itemCount; i++) {
      if (idToMarketItem[i + 1].owner == address(0)) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns only items that a user has purchased */
  function fetchMyNFTs() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == msg.sender) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns only items a user has created */
  function fetchItemsCreated() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == msg.sender) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }
}