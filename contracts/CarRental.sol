// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0 <0.8.27;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/Ownable.sol";


contract CarRental is ERC721, Ownable {

    struct Car {
        string model;
        string color; 
        uint256 year_of_matriculation;
        uint256 original_value;
    }

    uint256 public nextTokenId;
    mapping(uint256 => Car) public cars;      // Token ID to Car struct


    constructor() ERC721("CarRental", "CR") {}


    function createCar(
        string memory model,
        string memory color, 
        uint256 year_of_matriculation,
        uint256  original_value
        )public onlyOwner {
        uint256 tokenId = nextTokenId;
        cars[tokenId] = Car(model, color, year_of_matriculation, original_value);
        _safeMint(owner(), tokenId);
        nextTokenId++;

    }
}