// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0 <0.8.27;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/Ownable.sol";


/// @title CarLeasing
contract CarLeasing is ERC721, Ownable {

    // MilageCaps for the lease.
    uint[] public MilageCaps = [1000, 5000, 10000, 15000, 20000];

    // One month, two month, three months, six months, 12 months
    uint[] public ContractDuration = [30 days, 60 days, 90 days, 180 days, 360 days];


    // Used to track the state of the contract.
    enum State { Locked , Unlocked }

    // Task 1
    struct Car {
        string model;
        string color; 
        uint yearOfMatriculation;
        uint originalValue;
        uint milage;
    }

    struct Lease {
        State state; 
        uint monthlyQuota;
        address leasee;
        uint startTime;
        uint contractDuration;
        uint nextMonthlyPaymentDue;
        bool isActive;
        uint paidAmount;
    }
    
    // next car token id
    uint public nextTokenId;

    // Mapping of tokenID to car struct
    mapping(uint => Car) public cars;

    // Mapping of tokenID to lease struct. 
    // One car can only be in one lease, therefore we use the same token ID for cars and lease.
    mapping(uint => Lease) public leases;

    // Mapping to check if car is in an active lease. Used when creating a contract.
    mapping(uint => bool) public carInActiveLease;


    constructor() ERC721("CarLeasing", "CL") {}

    // Task 1
    // @notice Creates a new car as an NFT. The car can be leased to customers after creation.
    function createCar(
        string memory model,
        string memory color, 
        uint yearOfMatriculation,
        uint originalValue,
        uint milage
        )public onlyOwner {
        uint tokenId = nextTokenId;
        cars[tokenId] = Car(model, color, yearOfMatriculation, originalValue, milage);

        // Mint to create a NFT.
        _safeMint(owner(), tokenId);

        // Increment tokenId for the next car to be created.
        nextTokenId++;
    }

    // Task 3
    function calculateMonthlyQuota(
        uint originalValue,
        uint mileage,
        uint driverExperience,
        uint mileageCap,
        uint contractDuration
      ) private pure returns (uint) {
        // Making this function pure such that it cannot access any state nor change states

        // Add requirements to make sure there are no negative values.
        require(originalValue > 0, "Original car value must be greater than 0");
        require(driverExperience > 0, "Drives experience must be greater than 0");
        require(mileageCap > 0, "Mileage cap must be greater than 0");
        require(contractDuration > 0, "Contract duration must be greater than 0");
        // Calculates monthly quota for a car.

        // TODO: Use these values. We had a problem that the values became negative. This is not possible with uints.
        uint baseQuota = originalValue / 100; // Base monthly quota (for simplicity)
        uint experienceDiscount = driverExperience * 2; // Discount per experience year
        uint mileageFactor = mileage / 1000; // Increase based on mileage
        uint durationFactor = contractDuration > 12 ? 5 : 0; // Discount for long-term lease
        return 1;
    }

    // Task 3
    // @notice Registers a lease for an existing car. Lease is inactive untill confirmed by owner.
    function registerLease(
        uint tokenId,
        uint driverExperience,
        uint milageCapIndex,
        uint contractDurationIndex
        ) public payable {
            Car memory car = cars[tokenId];

            // Prevent index out of range errors.
            require(contractDurationIndex < ContractDuration.length, "contractDurationIndex out of range");
            require(milageCapIndex < MilageCaps.length, "milageCapIndex out of range");

            uint contractDuration = ContractDuration[contractDurationIndex];
            uint milageCap = MilageCaps[milageCapIndex];

            uint monthlyQuota = calculateMonthlyQuota(car.originalValue, car.milage, driverExperience , milageCap, contractDuration);
            uint downPayment = (3*monthlyQuota);
            require(msg.value >= downPayment + monthlyQuota, "Wrong payment amount");
            require(carInActiveLease[tokenId] == false, "Car is already leased");
            
            // Send back money that are over.
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
                // This funds are locked in the contract until owner has confirmed the lease.
                msg.value
            );

            // Set that the car is in an active lease.
            carInActiveLease[tokenId] = true;
    }

    // Task 3 (& 5c?)
    // @notice Confirms the lease by owner. Lease will become active, and funds will be transfered from leasee to owner of the car. 
    function confirmLease(uint tokenId) public onlyOwner {
        // Find lease for correct car with tokenId.
        Lease memory lease = leases[tokenId];

        // Needs to be locked. If not we will not transfer the funds.
        require(lease.state == State.Locked, "The lease is already confirmed.");

        // Find the address to the owner of the car (owner of the contract)
        address payable ownerPayable  = payable(owner());

        // Transfer money to owner
        ownerPayable.transfer(lease.paidAmount);
        
        // The lease is locked. 
        lease.state = State.Unlocked;

        // Start the lease when confirmed.
        lease.startTime = block.timestamp;

        // Lease is payed each 30 days. (suffix days converts days into seconds.)
        lease.nextMonthlyPaymentDue = lease.startTime + 30 days;

        // Store the modified lease object in the mapping.
        leases[tokenId] = lease;
    }

    // Task 3 & 4
    // @notice Used for paying the monthly fee for the lease.
    function payMonthlyQuota(uint tokenId) public payable {
        // Find lease for correct car with tokenId.
        Lease memory lease = leases[tokenId];
        
        require(msg.sender == lease.leasee, "Msg sender must be the same person as leasee.");
        require(msg.value  >= lease.monthlyQuota, "Wrong payment amount");
        
        address payable ownerPayable  = payable(owner());

        // Pay the owner of the contract. Should this be the car owner???
        ownerPayable.transfer(msg.value);

        // Extend the next monthly payment due with 30 days.
        // 30 days will be converted 30 days in seconds.
        lease.nextMonthlyPaymentDue += 30 days;

        // Store the modified lease object in the mapping.
        leases[tokenId] = lease;
    }

    // Task 4 & 5
    function terminateLease(uint tokenId) private onlyOwner {
        address carOwner = owner();
        Lease memory lease = leases[tokenId];
        require(msg.sender == carOwner || msg.sender == lease.leasee, "Car owner and leasee are the only people who can terminate the contract");

        // This is not really used for anything, maybe not have it???
        leases[tokenId].isActive = false;

        // The car can now be leased to other customers.
        carInActiveLease[tokenId] = false;
    }
    

    // Task 4
    function terminateLeaseIfMonthlyPaymentNotRecieved(uint tokenId) public onlyOwner{
        Lease memory lease = leases[tokenId];

        // Verify that the lease is Unlocked (started)
        require(lease.state == State.Unlocked, "The lease must be confirmed.");
        
        // The monthly quota is not payed for the given month + 2 days extra to be nice :).
        require(block.timestamp > (lease.startTime + lease.nextMonthlyPaymentDue + 2 days), "The leasee has payed the monthly quota for the given month. The contract will not be terminated.");

        // Lease is terminated.
        terminateLease(tokenId);
        
        // if (block.timestamp > lease.nextMonthlyPaymentDue + 2 days){
        //     // Lease has not payed, and the lease will be terminated by car owner.
            
        // }
    }

    // Task 5
    function leaseHasEnded(Lease memory lease) private view returns (bool){
        // Checks if the lease has ended.
        return block.timestamp >= lease.contractDuration + lease.startTime;
    }

    // Task 5
    function handleEndOfLease(uint tokenId, uint optionId) public {
        Lease memory lease = leases[tokenId];

        require(leaseHasEnded(lease), "Lease has not ended.");

        // Terminate the contract.
        if (optionId == 0){
            terminateLease(tokenId);
        }

        // Extend the lease by one year
        // Change the monthly quota payment.
        else if (optionId == 1) {
            // TODO : Create this function. Extend the lease and re-calculate monthly quota.
            // extendLeaseWithOneYear()
        }

        // Sign a lease with a new vehicle.
        else if (optionId == 2) {
            // Sets the car to not be in any active lease.
            // Should this also create a new lease??
            // TODO: Think about something smart here.

        }
    }
}