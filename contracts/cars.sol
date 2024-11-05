// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract CarLeasingNFT is ERC721("CarLeasingNFT", "CLNFT") {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    struct Car {
        string model;
        string color;
        uint16 year_of_matriculation;
        uint256 original_value;
    }

    struct LeaseDetail {
        uint256 org_value;
        uint256 current_mileage;
        uint8 driver_experience;
        uint256 mileage_cap;
        uint256 contract_duration;
    }

    struct Payment {
        address lessee;
        uint256 amount;
    }

    mapping(uint256 => Car) public cars;
    mapping(uint256 => LeaseDetail) public leaseDetails;
    mapping(uint256 => Payment[]) public payments;

    function mintCar(
        address to,
        string memory model,
        string memory color,
        uint16 year_of_matriculation,
        uint256 original_value,
        uint256 current_mileage,
        uint8 driver_experience,
        uint256 mileage_cap,
        uint256 contract_duration
    ) public {
        uint256 tokenId = _tokenIdTracker.current();

        cars[tokenId] = Car({
            model: model,
            color: color,
            year_of_matriculation: year_of_matriculation,
            original_value: original_value
        });

        leaseDetails[tokenId] = LeaseDetail({
            org_value: original_value,
            current_mileage: current_mileage,
            driver_experience: driver_experience,
            mileage_cap: mileage_cap,
            contract_duration: contract_duration
        });

        _safeMint(to, tokenId);
        _tokenIdTracker.increment();
    }
}