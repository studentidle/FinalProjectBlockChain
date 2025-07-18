// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

// REMINDER: Make sure to add documention thingy
/// @notice This is the Parent Contract
contract ConcertFactory {
    // This contract is a placeholder for the ConcertFactory
    // It can be extended with functions to generate concerts, set ticket price and maximum of ticket available

    address internal admin;
    ConcertContract[] public deployedConcerts;
    event DeployedConcerts(address indexed concertAddress, string _name, uint _price, uint _ticket , address _organizer);

    constructor() {
        admin = msg.sender;
    }

    /// @notice createConcert creates a new concert contract
    /// @param _name The name of the concert
    /// @param _price The price of the ticket for the concert   
    /// @param _ticket The total number of tickets available for the concert
    function createConcert(string memory _name, uint _price, uint _ticket, address _organizer ) public {
        require(msg.sender == admin, "Only admin can create a concert.");

        ConcertContract newConcert = new ConcertContract(_name, _price, _ticket, _organizer);
        deployedConcerts.push(newConcert);
        emit DeployedConcerts(address(newConcert), _name, _price, _ticket, _organizer);
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
    uint public ticketPrice;
    uint public totalTicket;
    address internal organizer;
    uint private ticketId = 1;
    bool public concertCancelled;

    struct Buyer {
        string name;
        address buyerAddress;
        uint ticketsPurchased;
        uint[] ticketIds;
    }

    mapping(address => Buyer) public buyers; // Buyer address → Buyer details
    mapping(uint => address) public ticketOwner; // Ticket ID → Owner
    mapping(uint => bool) public ticketUsed; // Ticket ID → Used status

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

    constructor(string memory _name, uint _price, uint _ticket, address _organizer) {
        concertName = _name;
        ticketPrice = _price;
        totalTicket = _ticket;
        organizer = _organizer;
        
    }

    /// @notice buyTicket allows customers to purchase tickets for the concert
    // They can only buy tickets one at a time. Idk if ilan pwede mahoard na tix ng isang buyer 
    function buyTicket(string memory _name) public payable isBuyer() {
        require(msg.value == ticketPrice, "Incorrect ticket price.");
        require(totalTicket > 0, "No tickets available.");
        require(ticketOwner[ticketId] == address(0), "Ticket already owned.");
        //require(ticketsOwned[msg.sender] < 1, "You can only purchase one ticket at a time.");

        //ADDED: Create customer record
        Buyer storage buyer = buyers[msg.sender];

        if (buyer.buyerAddress == address(0)) {
            // If first time buyer, set info
            buyer.buyerAddress = msg.sender;
            buyer.name = _name;
        }

        //ADDED: Update buyer's ticket purchase details
        buyer.ticketsPurchased++;
        buyer.ticketIds.push(ticketId);
        ticketOwner[ticketId] = msg.sender;

        //ADDED: Decrease total tickets available
        totalTicket--;

        //ADDED: Increment ticketId
        ticketId++;
    }

    /// @notice transferTicket Allows a ticket owner to gift or resell their ticket to another person
    /// @param ticketToTransfer ID of the ticket that will be resold/gifted
    /// @param ticketSeller Address of the recipient
    /// @param resellPrice Price at which the ticket will be sold at. (Resell price range is 0 to original buying price)
    function transferTicket(uint ticketToTransfer, address payable ticketSeller, uint resellPrice) public payable {
        require(ticketOwner[ticketToTransfer] == msg.sender, "Cannot transfer ticket to yourself.");
        require(ticketSeller == msg.sender, "Cannot transfer ticket to yourself.");
        require(resellPrice <= ticketPrice, "Resell price cannot exceed original ticket price."); // ADDED: Check if resell price is within range
        require(ticketUsed[ticketToTransfer] == false, "Ticket has already been used!"); // ADDED: Check if ticket has already been used
        
        if (resellPrice > 0) {
            // Transfer payment to the seller
            require(msg.value == resellPrice, "Incorrect resell price.");
            payable(msg.sender).transfer(msg.value);
        }

        //ADDED: Update ticket ownership
        ticketOwner[ticketToTransfer] = msg.sender;
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

    function getMyTickets() public view returns (uint[] memory) {
        return buyers[msg.sender].ticketIds; // Return the list of ticket IDs owned by the buyer
    }


}
