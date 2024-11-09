// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0 <0.8.27;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/Ownable.sol";


contract CarRental is ERC721, Ownable {

    // define some milage caps for the leasing deals
    // TODO: These enums needs to be used.
    uint256[] public MilageCaps = [1000, 5000, 10000, 15000, 20000];

    enum State { Locked , Unlocked }


    struct Car {
        string model;
        string color; 
        uint256 yearOfMatriculation;
        uint256 originalValue;
        uint256 milage;
    }

    struct Lease {
        State state; 
        uint256 monthly_quota;
        address leasee;
        uint256 start_date;
        uint256 contractDuration;
        uint nextMonthlyPaymentDue;
        bool isActive;
        uint256 paidAmount;
    }
    
    uint256 public nextTokenId;
    mapping(uint256 => Car) public cars;     // Token ID to Car struct
    mapping(uint256 => Lease) public leases; // Token ID to Leasing struct
    mapping(uint256 => bool) public carInActiveLease;


    constructor() ERC721("CarRental", "CR") {}


    function createCar(
        string memory model,
        string memory color, 
        uint256 yearOfMatriculation,
        uint256 originalValue,
        uint256 milage
        )public onlyOwner {
        uint256 tokenId = nextTokenId;
        cars[tokenId] = Car(model, color, yearOfMatriculation, originalValue, milage);

        // Mint to create a NFT.
        _safeMint(owner(), tokenId);
        nextTokenId++;

    }

    // Task 3
    function calculateMonthlyQuota(
        uint256 originalValue,
        uint256 mileage,
        uint256 driverExperience,
        uint256 mileageCap,
        uint256 contractDuration
      ) public pure returns (uint256) {
        // Calculates monthly quota for a car.

        // TODO: Use these values. We had a problem that the values became negative. This is not possible with uints.
        uint256 baseQuota = originalValue / 100; // Base monthly quota (for simplicity)
        uint256 experienceDiscount = driverExperience * 2; // Discount per experience year
        uint256 mileageFactor = mileage / 1000; // Increase based on mileage
        uint256 durationFactor = contractDuration > 12 ? 5 : 0; // Discount for long-term lease
        return 1;
    }

    // Task 3
    function registerLease(
        uint256 tokenId,
        uint256 milageCapIndex, // changed to this name instead of  `mileageCapIndex` for consistence with the function definition.
        uint256 driverExperience,
        uint256 contractDuration
        ) public payable {
            Car memory existingCar = cars[tokenId];
            uint256 monthlyQuota = calculateMonthlyQuota(existingCar.originalValue, existingCar.milage, driverExperience , MilageCaps[milageCapIndex], contractDuration );
            uint256 downPayment = (3*monthlyQuota);
            require(msg.value >= downPayment + monthlyQuota, "Wrong payment amount");
            require(carInActiveLease[tokenId] == false, "Car is already leased");
            

            leases[tokenId] = Lease(
                State.Locked,
                monthlyQuota,
                msg.sender,
                // Lease will start after lease if confirmed.
                0,
                contractDuration,
                // No next payment due before lease is confirmed.
                0,
                true,
                // TODO: This should only transfer the neccessary amount and give back the excess payment.
                msg.value
            );
            carInActiveLease[tokenId] = true;
    }

    // Task 3 (& 5c?)
    function confirmLease(uint256 tokenId) public onlyOwner {
        // Find lease for correct car with tokenId.
        Lease memory lease = leases[tokenId];

        // Needs to be locked. If not we will not transfer the funds.
        require(lease.state == State.Locked, "The lease cannot be confirmed yet");

        // Find the address to the owner of the car (owner of the contract)
        address payable ownerPayable  = payable(owner());

        // Transfer money to owner
        ownerPayable.transfer(lease.paidAmount);
        
        // The lease is locked. 
        lease.state = State.Unlocked;

        lease.nextMonthlyPaymentDue = 30;

        leases[tokenId] = lease;
    }

    // Task 3 & 4
    function payMonthlyQuota(uint256 tokenId) public payable {
        // Find lease for correct car with tokenId.
        Lease memory lease = leases[tokenId];
        
        require(msg.sender == lease.leasee, "Msg sender must be the same person as leasee.");
        require(msg.value  >= lease.monthly_quota, "Wrong payment amount");
        
        address payable ownerPayable  = payable(owner());

        // Pay the owner of the contract. Should this be the car owner???
        ownerPayable.transfer(msg.value);

        // Extend the next monthly payment due with 30 days.
        lease.nextMonthlyPaymentDue += 30 days;
    }

    // Task 4 & 5
    function terminateLease(uint tokenId) private {
        address carOwner = owner();
        Lease memory lease = leases[tokenId];
        require(msg.sender == carOwner || msg.sender == lease.leasee, "Car owner and leasee are the only people who can terminate the contract");

        // This is not really used for anything, maybe not have it???
        lease.isActive = false;

        // The car can now be leased to other customers.
        carInActiveLease[tokenId] = false;
    }
    

    // Task 4
    function terminateLeaseIfMonthlyPaymentNotRecieved(uint256 tokenId) public onlyOwner{
        Lease memory lease = leases[tokenId];

        // Verify that the lease is Unlocked (started)
        require(lease.state == State.Unlocked, "The lease must be confirmed.");

        // The monthly quota is not payed for the given month + 2 days extra to be nice :).
        if (block.timestamp > lease.nextMonthlyPaymentDue + 2 days){
            // Lease has not payed, and the lease will be terminated by car owner.
            terminateLease(tokenId);
        }

    }

    // Task 5
    function leaseHasEnded(Lease memory lease) private view returns (bool){
        // Checks if the lease has ended.
        return block.timestamp >= lease.contractDuration + lease.start_date;
    }

    // Task 5
    function handleEndOfLease(uint256 tokenId, uint optionId) public {
        Lease memory lease = leases[tokenId];

        require(leaseHasEnded(lease), "Lease has not ended.");

        // Terminate the contract.
        if (optionId == 0){
            terminateLease(tokenId);
        }

        // Extend the lease by one year
        else if (optionId == 1) {
            // TODO : Create this function.
            // extendLeaseWithOneYear()
        }

        // Sign a lease with a new vehicle.
        else if (optionId == 2) {
            // Sets the car to not be in any active lease.
            // Should this also create a new lease??
            carInActiveLease[tokenId] = false;

        }
    }
}