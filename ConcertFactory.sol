// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

// REMINDER: Make sure to add documention thingy
/// @notice This is the Parent Contract
contract ConcertFactory {
    // This contract is a placeholder for the ConcertFactory
    // It can be extended with functions to generate concerts, set ticket price and maximum of ticket available

    address internal admin;

    ConcertContract[] public deployedConcerts;

    event DeployedConcerts(
        address indexed concertAddress,
        string _name,
        uint[] _prices,
        uint[] _capacities,
        uint _maxTixPerBuyer,
        address _organizer,
        string _date
    );

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
        string memory _date
    ) public {
        require(msg.sender == admin, "Only admin can create a concert.");
        require(_prices.length == _capacities.length, "Please provide complete pricing details.");

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
    // This contract is a placeholder for the ConcertContract
    // It can be extended with functions to manage concert details, ticket sales, and attendance
    // For now, it serves as a base for future development

    string public concertName;
    // uint public ticketPrice; NOTE: We don't need this anymore because we have dynamic pricing already.
    uint public totalTixPerBuyer; // max number of ticket that can be bought
    string public expirationDate;

    address internal organizer;
    uint private ticketId = 1;
    bool private concertCancelled;

    enum SeatTier { GenAd, UpperBoxC, UpperBoxB, UpperBoxA, VIP }

    struct Buyer {
        string name;
        address buyerAddress;
        uint ticketsPurchased;
        uint[] ticketIds;
    }

    struct PendingTransfer {
        address resellBuyer;
        address seller;
        uint sellingPrice;
    }

    mapping(uint => PendingTransfer) public pendingTransfers;

    mapping(address => Buyer) public buyers; // Buyer address → Buyer details
    mapping(uint => address) public ticketOwner; // Ticket ID → Owner
    mapping(uint => bool) public ticketUsed; // Ticket ID → Used status
    mapping(SeatTier => uint) public ticketPrices; // Ticket Tier → Ticket Price
    mapping(uint => SeatTier) public ticketTier;
    mapping(SeatTier => uint) public tierCapacity; // Ticket Tier → Tier Capacity
    mapping (SeatTier => uint) public seatingSold;
    

    /// @notice Modifier that checks if the organizer called the function
    modifier isOrganizer() {
        require(msg.sender == organizer, "You are not the organizer!");
        _;
    }

    modifier isBuyer() {
        require(msg.sender != organizer, "Organizer cannot perform this action.");
        _;
    }

    event TicketUsed(address indexed buyer, uint indexed ticketId);

    event TicketTransferred(address indexed reseller, address indexed buyer, uint indexed ticketId);
    event TicketTransferDenied(address indexed reseller, address indexed buyer, uint indexed ticketId);
    event TransferPending(address indexed reseller, address indexed buyer, uint indexed ticketId);

    constructor(
        string memory _name,
        uint[] memory _prices,
        uint[] memory _capacities,
        uint _maxTixPerBuyer,
        address _organizer,
        string memory _date
    ) {
        concertName = _name;
        totalTixPerBuyer = _maxTixPerBuyer;
        organizer = _organizer;
        expirationDate = _date;

        for (uint i = 0; i < _prices.length; i++) {
            require(_prices[i] > 0, "Prices must be greater than zero.");
            require(_capacities[i] > 0, "Capacities must be greater than zero.");
            
            ticketPrices[SeatTier(i)] = _prices[i];
            tierCapacity[SeatTier(i)] = _capacities[i];
        }
    }

    /// @notice buyTicket allows customers to purchase tickets for the concert
    // They can only buy tickets one at a time. Idk if ilan pwede mahoard na tix ng isang buyer 
    function buyTicket(string memory _name, SeatTier _tier, uint _quantity) public payable isBuyer() {
        // Checks if the amount of tickets to be purchased is still
        // within the range of allowable ticket purchases.
        require(_quantity > 0 && _quantity <= totalTixPerBuyer, "Invalid quantity.");

        // Checks if there are available seats left
        require((seatingSold[_tier] + _quantity) <= tierCapacity[_tier], "There are no available seats!");

        // Checks if payment is correct (NOTE: total = ticket price * # of tickets)
        require(msg.value == (ticketPrices[_tier] * _quantity), "Incorrect ticket price.");
        require(ticketOwner[ticketId] == address(0), "Ticket already owned.");

        // Creates customer record
        Buyer storage buyer = buyers[msg.sender];

        if (buyer.buyerAddress == address(0)) {
            // If first time buyer, set info
            buyer.buyerAddress = msg.sender;
            buyer.name = _name;
        }

        for (uint i = 0; i < _quantity; i++) {
            // Updates buyer's ticket purchase details
            buyer.ticketsPurchased++;
            buyer.ticketIds.push(ticketId);
            ticketOwner[ticketId] = msg.sender;
            ticketTier[ticketId] = _tier;
            seatingSold[_tier]++;
            ticketId++; // Increments ticketId
        }
    }

    /// @notice transferTicket Allows a ticket owner to gift or resell their ticket to another person
    /// @param ticketToTransfer ID of the ticket that will be resold/gifted
    /// @param resellPrice Price at which the ticket will be sold at. (Resell price range is 0 to original buying price)
    function transferTicket(uint ticketToTransfer, uint resellPrice) public payable {
        address ticketSeller = ticketOwner[ticketToTransfer];
        require(ticketSeller != msg.sender, "Cannot transfer ticket to yourself.");
        require(resellPrice <= ticketPrices[ticketTier[ticketToTransfer]], "Resell price cannot exceed original ticket price."); // ADDED: Check if resell price is within range
        require(ticketUsed[ticketToTransfer] == false, "Ticket has already been used!"); // ADDED: Check if ticket has already been used
        require(msg.value == resellPrice, "Incorrect resell price.");

        // ADDED: Update pending transfer details
        PendingTransfer storage transfer = pendingTransfers[ticketToTransfer];
        require(transfer.resellBuyer == address(0), "Ticket already has a pending transfer.");
        transfer.resellBuyer = msg.sender;
        transfer.sellingPrice = resellPrice;
        transfer.seller = ticketSeller;

        emit TransferPending(ticketSeller, msg.sender, ticketToTransfer);
    }

    /// @notice confirmTransfer Allows seller to confirm the transfer intiated by the buyer
    /// @param ticketToTransfer ID of the ticket that will be transferred
    function confirmTransfer(uint ticketToTransfer, bool confirm) public  {
        PendingTransfer storage transfer = pendingTransfers[ticketToTransfer];
        address ticketSeller = ticketOwner[ticketToTransfer];
        address buyer = transfer.resellBuyer;
        uint price = transfer.sellingPrice;
        require(ticketSeller == msg.sender, "Only seller can confirm transfer.");
        require(ticketUsed[ticketToTransfer] == false, "Ticket has already been used!"); // ADDED: Check if ticket has already been used
        require(buyer != address(0), "No pending transfer.");

        if (confirm) {
            if (price > 0) {
                // Transfer payment to the seller
                payable(msg.sender).transfer(price);
            }
        //ADDED: Update ticket ownership
        ticketOwner[ticketToTransfer] = buyer;
        emit TicketTransferred(msg.sender, buyer, ticketToTransfer);
        } 
        else {
            if (price > 0) {
                payable(buyer).transfer(price);
            }
        emit TicketTransferDenied(msg.sender, buyer, ticketToTransfer);
        }

        delete pendingTransfers[ticketToTransfer];
    }

    /// @notice markTicket Allows the organizer to mark the buyer's ticket as used before entering the concert
    /// @param _ticketId Address of the ticket
    function markTicket(uint _ticketId) external isOrganizer {
        require(ticketOwner[_ticketId] != address(0), "Invalid ticket ID!"); // ADDED: Check if ticket ID is valid
        require(ticketUsed[_ticketId] == false, "Ticket has already been used!"); // ADDED: Check if ticket has already been used
        
        // ADDED: Update ticket status
        ticketUsed[_ticketId] = true;

        // ADDED: Record in the transaction logs
        emit TicketUsed(ticketOwner[_ticketId], _ticketId);
    }

    function cancelConcert() external isOrganizer {
        require(concertCancelled == false, "Concert has already been cancelled");
        concertCancelled = true;
    }

    function refundTickets() external isOrganizer {
        require(concertCancelled == true, "Concert is not cancelled.");

        for (uint i = 1; i < ticketId; i++) {
            address owner = ticketOwner[i];
            
            if (owner != address(0) && !ticketUsed[i]) {
                SeatTier tier = ticketTier[i]; // stores the tier of the ticketId
                uint refundPrice = ticketPrices[tier]; // stores the price of the seat tier
                payable(owner).transfer(refundPrice);
                ticketOwner[i] = address(0); // removes ownership of the ticketId
            }
        }
    }

    function getMyTickets() public view returns (uint[] memory) {
        return buyers[msg.sender].ticketIds; // Return the list of ticket IDs owned by the buyer
    }
}