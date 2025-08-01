// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStreamingContractV1 {
    struct Stream {
        address recipient;
        address sender;
        uint256 startTime;
        uint256 endTime;
        uint256 totalAmount;
        uint256 withdrawnAmount;
    }

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime
    );
    
    event Withdrawal(
        uint256 indexed streamId,
        address indexed recipient,
        uint256 amount
    );

    // Create a new ETH stream (totalAmount comes from msg.value)
    function createStream(
        address recipient,
        uint256 startTime,
        uint256 endTime
    ) external payable returns (uint256 streamId);

    // Withdraw available funds from a stream
    function withdrawFromStream(uint256 streamId) external;

    // View stream details
    function getStream(uint256 streamId) external view returns (Stream memory);

    // Check withdrawable amount
    function calculateWithdrawableAmount(uint256 streamId) external view returns (uint256);
}