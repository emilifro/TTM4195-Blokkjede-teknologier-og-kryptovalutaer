// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0 <0.8.27;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/Ownable.sol";


/// @title CarLeasing
contract CarLeasing is ERC721, Ownable {

    // mileageCaps for the lease.
    uint[] public MileageCaps = [1000, 5000, 10000, 15000, 20000];

    // One month, two month, three months, six months, 12 months
    uint[] public ContractDuration = [30 days, 60 days, 90 days, 180 days, 365 days];


    // Used to track the state of the contract.
    enum State { Locked , Unlocked }

    // Task 1
    struct Car {
        string model;
        string color; 
        uint yearOfMatriculation;
        uint originalValue;
        uint mileage;
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
        uint driverExperience;
        uint mileageCap;
    }
    
    // next car token id
    uint public nextTokenId;

    // Mapping of tokenID to car struct
    mapping(uint => Car) public cars;

    // Mapping of tokenID to lease struct. 
    // One car can only be in one lease, therefore we use the same token ID for cars and lease.
    mapping(uint => Lease) public leases;


    constructor() ERC721("CarLeasing", "CL") {}

    // Task 1
    // @notice Creates a new car as an NFT. The car can be leased to customers after creation.
    function createCar(
        string memory model,
        string memory color, 
        uint yearOfMatriculation,
        uint originalValue,
        uint mileage
        )public onlyOwner {
        uint tokenId = nextTokenId;
        cars[tokenId] = Car(model, color, yearOfMatriculation, originalValue, mileage);

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
        // Pure functions do not cost any gas

        // Add requirements to make sure there are no negative values.
        require(originalValue > 0, "Original car value must be greater than 0");
        require(driverExperience > 0, "Driver experience must be greater than 0");
        require(mileageCap > 0, "Mileage cap must be greater than 0");
        require(contractDuration > 0, "Contract duration must be greater than 0");
        // Calculates monthly quota for a car.

        
        uint baseQuota = originalValue / 100; // 1% of car value

        // Given that mileage will have an impact: a mileage of 100 000 should might reduce the quota by 10%

        uint mileageReduction = baseQuota * mileage / 1000000;

        uint insuranceCost = baseQuota * 10 / (100 + driverExperience * 5); // Reduces from 10% of base quota

        uint mileageCapReduction;
        if (mileageCap == 1000) {
            mileageCapReduction = baseQuota / 5; //20% reduction
        } else if (mileageCap == 5000) {
            mileageCapReduction = baseQuota / 10; //10% reduction
        } else if (mileageCap == 10000) {
            mileageCapReduction = baseQuota / 20; //5% reduction
        } else if (mileageCap == 15000) {
            mileageCapReduction = baseQuota / 100; //1% reduction
        } else if (mileageCap == 20000) {
            mileageCapReduction = 0; //0 % reduction
        } else {
            revert("Unsupported mileage cap");
        }
        // 10% reduction if contract is longer than 3 months
        uint contractDurationReduction = (contractDuration >= 90 days) ? baseQuota / 10 : 0;

        return baseQuota - mileageReduction - mileageCapReduction - contractDurationReduction + insuranceCost;
    }

    // Task 3
    // @notice Registers a lease for an existing car. Lease is inactive until confirmed by owner.
    function registerLease(
        uint tokenId,
        uint driverExperience,
        uint mileageCapIndex,
        uint contractDurationIndex
        ) public payable {
            Car memory car = cars[tokenId];

            // Prevent index out of range errors.
            require(contractDurationIndex < ContractDuration.length, "contractDurationIndex out of range");
            require(mileageCapIndex < MileageCaps.length, "mileageCapIndex out of range");

            uint contractDuration = ContractDuration[contractDurationIndex];
            uint mileageCap = MileageCaps[mileageCapIndex];

            uint monthlyQuota = calculateMonthlyQuota(car.originalValue, car.mileage, driverExperience , mileageCap, contractDuration);
            uint downPayment = (3*monthlyQuota);
            require(msg.value >= downPayment + monthlyQuota, "Wrong payment amount");
            require(leases[tokenId].isActive == false, "Error");
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
                // This funds are locked in the contract until owner has confirmed the lease.
                msg.value,
                driverExperience,
                mileageCap
            );
    }

    // Task 3
    // @notice Confirms the lease by owner. Lease will become active, and funds will be transfered from leasee to owner of the car. 
    function confirmLease(uint tokenId) public onlyOwner {
        // Find lease for correct car with tokenId.
        Lease memory lease = leases[tokenId];

        // Needs to be locked. If not we will not transfer the funds.
        require(lease.state == State.Locked, "The lease is already confirmed.");

        // Find the address to the owner of the car (owner of the contract)
        address payable ownerPayable  = payable(owner());

        // Transfer money to owner
        ownerPayable.transfer(lease.monthlyQuota);
        lease.paidAmount -= lease.monthlyQuota;
        // The lease is confirmed. 
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

        uint overpay = msg.value - lease.monthlyQuota;

        lease.paidAmount += overpay;
        // Pay the owner of the contract. Should this be the car owner???
        ownerPayable.transfer(msg.value - overpay);

        // Extend the next monthly payment due with 30 days.
        // 30 days will be converted 30 days in seconds.
        lease.nextMonthlyPaymentDue += 30 days;

        // Store the modified lease object in the mapping.
        leases[tokenId] = lease;
    }

    // Task 4 & 5
    function terminateLease(uint tokenId, uint addedMileage) private onlyOwner {
        // address carOwner = owner();
        Lease memory lease = leases[tokenId];
        
        // Update car mileage
        cars[tokenId].mileage += addedMileage;

        // Deposit will be payed back
        payable(lease.leasee).transfer(lease.paidAmount);

        // Another lease can be signed for this car
        leases[tokenId].isActive = false;
    }
    

    // Task 4
    function terminateLeaseIfMonthlyPaymentNotRecieved(uint tokenId, uint addedMileage) public onlyOwner{
        Lease memory lease = leases[tokenId];

        // Verify that the lease is Unlocked (started)
        require(lease.state == State.Unlocked, "The lease must be confirmed.");
        
        // The monthly quota is not payed for the given month.
        require(block.timestamp > (lease.startTime + lease.nextMonthlyPaymentDue), "The leasee has payed the monthly quota for the given month. The contract will not be terminated.");

        // Lease is terminated.
        terminateLease(tokenId, addedMileage);
    }

    // Task 5

    /*
    @notice Returns whether the lease has ended or not  
    @return true if current date is after the end date of the lease 
    @Param lease includes leasing detials like startime and contract duration 
    */
    function leaseHasEnded(Lease memory lease) private view returns (bool){
        // Checks if the lease has ended.
        return block.timestamp >= lease.contractDuration + lease.startTime;
    }

    /*
    @notice Terminates lease if the lease has ended  
    @Param tokenId is the car lease that whish to be terminated
    @Param addedMilage is the milage the lessee has added to the car 
    */
    function terminateLeaseOnEnd(uint tokenId, uint addedMileage) public {
        Lease memory lease = leases[tokenId];
        
        //Checks if the lease has ended 
        require(leaseHasEnded(lease), "Lease has not ended.");

        //Terminate the lease 
        terminateLease(tokenId, addedMileage);
    }

    /*
    @notice Extend the duration of a lease when it has ended and update leasing details
    @Param tokenId is the car lease that whish to be extended
    @Param addedMilage is the milage the lessee has added to the car 
    */
    function extendLeaseOnEnd(uint tokenId, uint addedMileage) public {
        Lease memory lease = leases[tokenId];

        //Checks if the lease has ended 
        require(leaseHasEnded(lease), "Lease has not ended.");

        //add mileage to the leased car when the lease has ended 
        cars[tokenId].mileage += addedMileage;

        //Calculate the new monthly quota after the mileage has been updated
        uint newQuota = calculateMonthlyQuota(cars[tokenId].originalValue, cars[tokenId].mileage, lease.driverExperience, lease.mileageCap, lease.contractDuration);
        
        //Check if the new montnly quoata is lower than the previous quoata before updating quota in lease
        if (newQuota < lease.monthlyQuota) {
            lease.monthlyQuota = newQuota;
        }

        //Update the duration of the lease with 1 year 
        lease.contractDuration += 365 days;

        //Update and extend the lease based on new details 
        leases[tokenId] = lease;

    }

    /*
    @notice Terminate the pervious lease and register a new lease for a new car
    @Param tokenId is the car lease that whish to be extended
    @Param addedMilage is the milage the lessee has added to the car 
    @Param newToken is the new car and lease created 
    @Param driverExperience is how long the driver has had its licence 
    @Param mileageCapIndex is how long the driver can drive the car with the new lease 
    @Param contractDurationIndex is the duration of the new lease 
    */
    function registerNewLeaseOnEnd(
        uint tokenId, 
        uint addedMileage,
        uint newTokenId,
        uint driverExperience,
        uint mileageCapIndex,
        uint contractDurationIndex) public {
        
        //Terminates the previous contract 
        terminateLeaseOnEnd(tokenId, addedMileage);

        //Register a lease for a new car 
        registerLease(newTokenId, driverExperience, mileageCapIndex, contractDurationIndex);
    }
}