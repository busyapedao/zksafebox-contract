//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./ZkSafebox.sol";
import "./NameService.sol";
import "hardhat/console.sol";

contract SafeboxHelp {

    ZkSafebox zkSafebox;

    NameService nameService;


    constructor(address zkSafeboxAddr, address nameServiceAddr) {
        zkSafebox = ZkSafebox(zkSafeboxAddr);
        nameService = NameService(nameServiceAddr);
    }
    

    function rechargeCheckName(
        string memory name,
        address sender,
        address owner,
        address tokenAddr,
        uint256 amount
    ) public {
        require(
            keccak256(abi.encodePacked(name)) ==
                keccak256(abi.encodePacked(nameService.nameOf(owner))),
            "SafeboxHelp::recharge: name error"
        );

        zkSafebox.recharge(sender, owner, tokenAddr, amount);
    }
}
