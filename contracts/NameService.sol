//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


contract NameService {

    event SetName(
        address indexed user,
        string indexed name
    );

    mapping(address => string) public nameOf;


    constructor() {}


    function setName(string memory name) public {
        nameOf[msg.sender] = name;
        emit SetName(msg.sender, name);
    }

}