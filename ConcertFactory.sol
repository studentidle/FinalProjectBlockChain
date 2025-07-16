// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

// REMINDER: Make sure to add documention thingy
// Parent Contract
contract ConcertFactory {
    // This contract is a placeholder for the ConcertFactory
    // It can be extended with functions to generate concerts and tickets
    // For now, it serves as a base for future development

    address internal admin;

    ConcertContract[] public deployedConcerts;

    event DeployedConcerts(address indexed concertAddress, string _name, uint price, uint totalTicket);

    constructor() {
        admin = msg.sender;
    }

    function createConcert(string _name, uint _price, uint _ticket) public {
        require(msg.sender == sender, "Only admin can create a concert.");

        ConcertContract newConcert = new ConcertContract(_name, _price, _ticket);
        deployedConcerts.push(newConcert);

        emit DeployedConcerts(newConcert, _name, _price, _ticket);
    }

    function getDeployedConcerts() public view returns (ConcertContract[] memory) {
        return deployedConcerts;
    }
 }

contract ConcertContract {
    // This contract is a placeholder for the ConcertContract
    // It can be extended with functions to manage concert details, ticket sales, and attendance
    // For now, it serves as a base for future development

    string public concertName;
    uint public ticketPrice;
    uint public totalTicket;

    constructor(string _name, uint _price, uint _ticket) {
        concertN
    }
}