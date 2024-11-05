// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0 <0.8.27;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/Ownable.sol";


contract CarRental is ERC721, Ownable {

    // define some milage caps for the leasing deals
    uint256[] public MilageCaps = [1000, 5000, 10000, 15000, 20000];

    struct Car {
        string model;
        string color; 
        uint256 year_of_matriculation;
        uint256 original_value;
        uint256 milage;
    }

    struct Lease {
        uint256 monthly_quota;
        address leasee;
        uint256 start_date;
        uint256 contract_duration;
    }

    uint256 public nextTokenId;
    uint256 public nextLeaseId;
    mapping(uint256 => Car) public cars;     // Token ID to Car struct
    mapping(uint256 => Lease) public leases; // Token ID to Leasing struct


    constructor() ERC721("CarRental", "CR") {}


    function createCar(
        string memory model,
        string memory color, 
        uint256 year_of_matriculation,
        uint256 original_value,
        uint256 milage
        )public onlyOwner {
        uint256 tokenId = nextTokenId;
        cars[tokenId] = Car(model, color, year_of_matriculation, original_value, milage);
        _safeMint(owner(), tokenId);
        nextTokenId++;

    }

    function getCar(uint256 _carId) public view returns (Car memory) {
    return cars[_carId];
    }

    function registerLease(
        uint256 carId,
        address leassee,
        uint256 milageCapIndex, // changed to this name instead of  `mileageCapIndex` for consistence with the function definition.
        uint256 driverExperience,
        uint256 contractDuration,
        uint256 startDate
        ) public {
            Car memory existingCar = getCar(carId);
            uint256 monthlyQuota = calculateMonthlyQuota(existingCar.original_value, existingCar.milage, driverExperience , MilageCaps[milageCapIndex], contractDuration );
            uint256 downPayment = (3*monthlyQuota);
            uint256 leaseId = nextLeaseId;
            leases[leaseId] = Lease(monthlyQuota,leassee,startDate,contractDuration);

        }

    // function to calculate monthly quota for a car
    function calculateMonthlyQuota(
        uint256 originalValue,
        uint256 mileage,
        uint256 driverExperience,
        uint256 mileageCap,
        uint256 contractDuration
      ) public pure returns (uint256) {
          return (
              ((originalValue * 1000000) / 10000000 - 
                  (mileage * 100000)   / 100000 + 
                (10000000 - driverExperience * 200)) +
               contractDuration + mileageCap);
      }
}