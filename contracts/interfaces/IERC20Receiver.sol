// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title ERC20 token receiver interface
 * @dev Interface for any contract that wants to support transfers
 * from ERC20 asset contracts.
 */
interface IERC20Receiver {
    /**
     * @dev Whenever an {IERC20} token is transferred to this contract via {IERC20-transferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC20Receiver.onERC20Received.selector`.
     */
    function onERC20Received(
        address operator,
        address from,
        uint256 amount,
        bytes calldata data
    ) external returns (bytes4);
}
