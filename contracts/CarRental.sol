// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0 <0.8.27;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/Ownable.sol";


contract CarRental is ERC721, Ownable {

    // define some milage caps for the leasing deals
    uint256[] public MilageCaps = [1000, 5000, 10000, 15000, 20000];

    enum State { Locked , Unlocked }

    struct Car {
        string model;
        string color; 
        uint256 year_of_matriculation;
        uint256 original_value;
        uint256 milage;
    }

    struct Lease {
        State state; 
        uint256 monthly_quota;
        address leasee;
        uint256 start_date;
        uint256 contract_duration;
        bool isActive;
        uint256 paidAmount;
    }
    
    uint256 public nexttokenId;
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
        uint256 tokenId = nexttokenId;
        cars[tokenId] = Car(model, color, year_of_matriculation, original_value, milage);
        _safeMint(owner(), tokenId);
        nexttokenId++;

    }

    function getCar(uint256 _tokenId) public view returns (Car memory) {
    return cars[_tokenId];
    }

    function registerLease(
        uint256 tokenId,
        uint256 milageCapIndex, // changed to this name instead of  `mileageCapIndex` for consistence with the function definition.
        uint256 driverExperience,
        uint256 contractDuration
        ) public payable {
            Car memory existingCar = getCar(tokenId);
            uint256 monthlyQuota = calculateMonthlyQuota(existingCar.original_value, existingCar.milage, driverExperience , MilageCaps[milageCapIndex], contractDuration );
            uint256 downPayment = (3*monthlyQuota);
            require(msg.value >= downPayment + monthlyQuota, "Insufficient funds");

            leases[tokenId] = Lease(
            State.Locked,
            monthlyQuota,
            msg.sender,
            block.timestamp,
            contractDuration,
            true,
            msg.value
        );
        }

    // function to calculate monthly quota for a car
    function calculateMonthlyQuota(
        uint256 originalValue,
        uint256 mileage,
        uint256 driverExperience,
        uint256 mileageCap,
        uint256 contractDuration
      ) public pure returns (uint256) {
        //write more readable code
        uint256 baseQuota = originalValue / 100; // Base monthly quota (for simplicity)
        uint256 experienceDiscount = driverExperience * 2; // Discount per experience year
        uint256 mileageFactor = mileage / 1000; // Increase based on mileage
        uint256 durationFactor = contractDuration > 12 ? 5 : 0; // Discount for long-term lease
        //h
        return 1;
      }

}