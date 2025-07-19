// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

/// @notice This is the Parent Contract
contract ConcertFactory {
    // This contract has functions to generate concerts, set ticket price, capacities and maximum of tickets per buyer
    // It also has functions to get the list of deployed concerts.

    address internal admin; // Address of the admin who can create concerts

    ConcertContract[] public deployedConcerts; // Array to store deployed concert contracts

    /// @notice Event emitted when a new concert is deployed
    event DeployedConcerts(
        address indexed concertAddress,
        string _name,
        uint[] _prices,
        uint[] _capacities,
        uint _maxTixPerBuyer,
        address _organizer,
        uint _date
    );

    /// @notice Constructor sets the admin address
    constructor() {
        admin = msg.sender;
    }

    /// @notice createConcert creates a new concert contract
    /// @param _name The name of the concert
    /// @param _prices The price of the ticket for the concert
    /// @param _capacities The seating capacities for each ticket tier
    /// @param _maxTixPerBuyer The total number of tickets available for the concert
    /// @param _organizer The address of the concert organizer
    /// @param _date The date of the concert and expiration of the ticket
    function createConcert(
        string memory _name,
        uint[] memory _prices,
        uint[] memory _capacities,
        uint _maxTixPerBuyer,
        address _organizer,
        uint _date
    ) public {
        require(msg.sender == admin, "Only admin can create a concert.");
        require(_prices.length == _capacities.length, "Please provide complete pricing details.");
        require(block.timestamp < _date, "Concert date must be in the future.");

        ConcertContract newConcert = new ConcertContract(_name, _prices, _capacities, _maxTixPerBuyer, _organizer, _date);
        deployedConcerts.push(newConcert);

        emit DeployedConcerts(address(newConcert), _name, _prices, _capacities, _maxTixPerBuyer, _organizer, _date);
    }

    /// @notice getDeployedConcerts returns the list of deployed concert contracts
    function getDeployedConcerts() public view returns (ConcertContract[] memory) {
        return deployedConcerts;
    }
 }


/// @notice This is the Child Contract of ConcertFactory
contract ConcertContract {
    // This contract has functions to manage concert details, purchasing tickets, transfers, and cancellations.

    string public concertName; // Name of the concert
    uint public totalTixPerBuyer; // max number of ticket that can be bought of each buyer
    uint public expirationDate; // Date of the concert and expiration of the ticket

    address internal organizer; // Address of the concert organizer
    uint private ticketId = 1; // Unique ID for each ticket
    bool private concertCancelled; // Flag to check if the concert is cancelled

    /// @notice Enum for different seat tiers
    enum SeatTier { GenAd, UpperBoxC, UpperBoxB, UpperBoxA, VIP }

    /// @notice Struct to represent a buyer
    struct Buyer {
        string name;
        address buyerAddress;
        uint ticketsPurchased;
        uint[] ticketIds;
    }

    /// @notice Struct to represent a pending ticket transfer
    struct PendingTransfer {
        address resellBuyer;
        address seller;
        uint sellingPrice;
    }

    mapping(uint => PendingTransfer) public pendingTransfers; // Ticket ID → Pending Transfer Details
    mapping(address => Buyer) public buyers; // Buyer Dddress → Buyer Details
    mapping(uint => address) public ticketOwner; // Ticket ID → Owner
    mapping(uint => bool) public ticketUsed; // Ticket ID → Used Status
    mapping(SeatTier => uint) public ticketPrices; // Ticket Tier → Ticket Price
    mapping(uint => SeatTier) public ticketTier; // Ticket ID → Seat Tier
    mapping(SeatTier => uint) public tierCapacity; // Seat Tier → Tier Capacity
    mapping (SeatTier => uint) public seatingSold; // Seat Tier → sets the number of tickets sold for each tier

    /// @notice Modifier that checks if the organizer called the function
    modifier isOrganizer() {
        require(msg.sender == organizer, "You are not the organizer!");
        _;
    }
    
    /// @notice Modifier that checks if the caller is a buyer
    modifier isBuyer() {
        require(msg.sender != organizer, "Organizer cannot perform this action.");
        _;
    }
 
    /// @notice Modifier that checks if the ticket has not expired
    modifier hasTicketExpired() {
        require(block.timestamp <= expirationDate, "Ticket has expired.");
        _;
    }

    /// @notice Modifier that checks if the concert has not been cancelled
    modifier concertNotCancelled() {
        require(concertCancelled == false, "Concert has already been cancelled");
        _;
    }

    event TicketUsed(address indexed buyer, uint indexed ticketId); // Event emitted when a ticket is marked as used
    event TransferPending(address indexed reseller, address indexed buyer, uint indexed ticketId); // Event emitted when a ticket transfer is pending
    event TicketTransferred(address indexed reseller, address indexed buyer, uint indexed ticketId); // Event emitted when a ticket is successfully transferred
    event TicketTransferDenied(address indexed reseller, address indexed buyer, uint indexed ticketId); // Event emitted when a ticket transfer is denied

    /// @notice Constructor initializes the concert details
    /// @param _name The name of the concert
    /// @param _prices The price of the ticket for the concert
    /// @param _capacities The seating capacities for each ticket tier
    /// @param _maxTixPerBuyer The total number of tickets available for the concert
    /// @param _organizer The address of the concert organizer
    /// @param _date The date of the concert and expiration of the ticket
    constructor(
        string memory _name,
        uint[] memory _prices,
        uint[] memory _capacities,
        uint _maxTixPerBuyer,
        address _organizer,
        uint _date
    ) {
        concertName = _name;
        totalTixPerBuyer = _maxTixPerBuyer;
        organizer = _organizer;
        expirationDate = _date;

    // ADDED: Initialize ticket prices and capacities for each tier
        for (uint i = 0; i < _prices.length; i++) {
            require(_prices[i] > 0, "Prices must be greater than zero.");
            require(_capacities[i] > 0, "Capacities must be greater than zero.");
            
            ticketPrices[SeatTier(i)] = _prices[i];
            tierCapacity[SeatTier(i)] = _capacities[i];
        }
    }

    /// @notice buyTicket allows customers to purchase tickets for the concert
    /// @param _name The name of the buyer
    /// @param _tier The seat tier the buyer wants to purchase
    /// @param _quantity The number of tickets the buyer wants to purchase
    function buyTicket(string memory _name, SeatTier _tier, uint _quantity) public payable isBuyer hasTicketExpired concertNotCancelled {
        require(_quantity > 0 && _quantity <= totalTixPerBuyer, "Invalid quantity.");
        require(buyers[msg.sender].ticketsPurchased + _quantity <= totalTixPerBuyer, "Exceeds ticket purchase limit.");
        require((seatingSold[_tier] + _quantity) <= tierCapacity[_tier], "There are no available seats!");
        require(msg.value == (ticketPrices[_tier] * _quantity), "Incorrect ticket price.");
        require(ticketOwner[ticketId] == address(0), "Ticket already owned.");

        // Creates a new buyer if they don't exist
        Buyer storage buyer = buyers[msg.sender];

        if (buyer.buyerAddress == address(0)) {
            buyer.buyerAddress = msg.sender;
            buyer.name = _name;
        }
        
        // Updates buyer's ticket details
        for (uint i = 0; i < _quantity; i++) {
            buyer.ticketsPurchased++;
            buyer.ticketIds.push(ticketId);
            ticketOwner[ticketId] = msg.sender;
            ticketTier[ticketId] = _tier;
            seatingSold[_tier]++;
            ticketId++;
        }
    }

    /// @notice transferTicket Allows a ticket owner to gift or resell their ticket to another person
    /// @param ticketToTransfer ID of the ticket that will be resold/gifted
    /// @param resellPrice Price at which the ticket will be sold at. (Resell price range is 0 to original buying price)
    function transferTicket(uint ticketToTransfer, uint resellPrice) public payable hasTicketExpired concertNotCancelled {
        address ticketSeller = ticketOwner[ticketToTransfer];

        require(ticketSeller != msg.sender, "Cannot transfer ticket to yourself.");

        // Checks if resell price is within range
        require(resellPrice <= ticketPrices[ticketTier[ticketToTransfer]], "Resell price cannot exceed original ticket price.");

        // Checks if ticket has already been used
        require(ticketUsed[ticketToTransfer] == false, "Ticket has already been used!");
        require(msg.value == resellPrice, "Incorrect resell price.");

        // Updates pending transfer details
        PendingTransfer storage transfer = pendingTransfers[ticketToTransfer];

        require(transfer.resellBuyer == address(0), "Ticket already has a pending transfer.");
        transfer.resellBuyer = msg.sender;
        transfer.sellingPrice = resellPrice;
        transfer.seller = ticketSeller;

        emit TransferPending(ticketSeller, msg.sender, ticketToTransfer);
    }

    /// @notice confirmTransfer Allows seller to confirm the transfer intiated by the buyer
    /// @param ticketToTransfer ID of the ticket that will be transferred
    /// @param confirm Boolean to confirm or deny the transfer
    function confirmTransfer(uint ticketToTransfer, bool confirm) public hasTicketExpired concertNotCancelled {
        PendingTransfer storage transfer = pendingTransfers[ticketToTransfer];

        address ticketSeller = ticketOwner[ticketToTransfer];
        address newBuyer = transfer.resellBuyer;
        uint price = transfer.sellingPrice;

        require(ticketSeller == msg.sender, "Only seller can confirm transfer.");

        // Checks if ticket has already been used
        require(ticketUsed[ticketToTransfer] == false, "Ticket has already been used!");
        require(newBuyer != address(0), "No pending transfer.");

        if (confirm) {
            if (price > 0) {
                // Transfers payment to the seller
                payable(msg.sender).transfer(price);
            }

            // Updates ticket ownership
            ticketOwner[ticketToTransfer] = newBuyer;

            uint[] storage sellerTickets = buyers[msg.sender].ticketIds;
            for (uint i = 0; i < sellerTickets.length; i++) {
                if (sellerTickets[i] == ticketToTransfer) {
                    sellerTickets[i] = sellerTickets[sellerTickets.length - 1];
                    sellerTickets.pop();
                    break;
                }
            }

            // Checks if new buyer is receiving a ticket for the first time
            if (buyers[newBuyer].buyerAddress == address(0)) {
                buyers[newBuyer].buyerAddress = newBuyer;
                buyers[newBuyer].name = "Secondary Buyer";
            }

            buyers[newBuyer].ticketIds.push(ticketToTransfer);
            buyers[newBuyer].ticketsPurchased++;

            emit TicketTransferred(msg.sender, newBuyer, ticketToTransfer);
        } 
        else {
            if (price > 0) {
                payable(newBuyer).transfer(price);
            }

            emit TicketTransferDenied(msg.sender, newBuyer, ticketToTransfer);
        }

        delete pendingTransfers[ticketToTransfer];
    }

    /// @notice markTicket Allows the organizer to mark the buyer's ticket as used before entering the concert
    /// @param _ticketId Address of the ticket
    function markTicket(uint _ticketId) external isOrganizer concertNotCancelled {
        // Checks if ticket ID is valid
        require(ticketOwner[_ticketId] != address(0), "Invalid ticket ID!");

        // Checks if ticket has already been used
        require(ticketUsed[_ticketId] == false, "Ticket has already been used!");
        
        // Updates ticket status
        ticketUsed[_ticketId] = true;

        // Records in the transaction logs
        emit TicketUsed(ticketOwner[_ticketId], _ticketId);
    }

    /// @notice cancelConcert Allows the organizer to cancel the concert
    function cancelConcert() external isOrganizer concertNotCancelled {
        concertCancelled = true;
    }

    /// @notice refundTickets Allows the organizer to refund tickets if the concert is cancelled
    function refundTickets() external isOrganizer {
        require(concertCancelled == true, "Concert is not cancelled.");

        for (uint i = 1; i < ticketId; i++) {
            address owner = ticketOwner[i];
            
            if (owner != address(0) && !ticketUsed[i]) {
                SeatTier tier = ticketTier[i]; // Stores the tier of the ticketId
                uint refundPrice = ticketPrices[tier]; // Stores the price of the seat tier
                payable(owner).transfer(refundPrice);
                ticketOwner[i] = address(0); // Removes ownership of the ticketId
            }
        }
    }

    /// @notice addTicketCapacity allows the organizer to increase the capacity of a specific seat tier
    function addTicketCapacity(SeatTier _tier, uint _additionalCapacity) public isOrganizer concertNotCancelled {
        require(_additionalCapacity > 0, "Additional capacity must be greater than zero.");
        tierCapacity[_tier] += _additionalCapacity; // Increases the capacity for the specified tier
    }

    /// @notice modifyTicketPrice allows the organizer to change the price of a specific seat tier
    function modifyTicketPrice(SeatTier _tier, uint _newPrice) public isOrganizer concertNotCancelled {
        require(_newPrice > 0, "New price must be greater than zero.");
        ticketPrices[_tier] = _newPrice; // Updates the price for the specified tier
    }

    /// @notice getConcertDetails returns the details of the concert
    function getMyTickets() public view returns (uint[] memory) {
        return buyers[msg.sender].ticketIds; // Returns the list of ticket IDs owned by the buyer
    }
}