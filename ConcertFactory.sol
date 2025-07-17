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
    address public customer;

    constructor(string memory _name, uint _price, uint _ticket, address _organizer) {
        concertName = _name;
        ticketPrice = _price;
        totalTicket = _ticket;
        organizer = _organizer;
    }

    




}