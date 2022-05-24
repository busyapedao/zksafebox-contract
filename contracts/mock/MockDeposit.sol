//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../interfaces/IERC20Receiver.sol";
import "hardhat/console.sol";

contract MockDeposit is IERC20Receiver {

    address public zkSafeboxAddr;

    mapping(address => mapping(address => uint)) public token2user2amount;


    constructor(address _zkSafeboxAddr) {
        zkSafeboxAddr = _zkSafeboxAddr;
    }


    function onERC20Received(
        address operator,
        address from,
        uint256 amount,
        bytes calldata data
    ) external override returns (bytes4) {
        
        if (msg.sender == zkSafeboxAddr) {
            address tokenAddr = abi.decode(data, (address));
            token2user2amount[tokenAddr][operator] += amount;
            return this.onERC20Received.selector;
        }

        revert("MockDeposit::onERC20Received: unknow deposit");
    }
}
