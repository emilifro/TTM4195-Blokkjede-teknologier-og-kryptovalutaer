pragma solidity >= 0.8.0 <0.8.27;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CarRental is ERC721, Ownable {

    struct Car {
        string model;
        string color; 
        uint64 year_of_matriculation;
        uint64 original_value;
    }

    constructor(address initialOwner) {

    }
}