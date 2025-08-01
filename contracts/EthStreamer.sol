// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

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

    /// Invalid start time.
    error Streaming_InvalidStartTime();
    /// Stream does not exist.
    error Streaming_StreamNotExist();
    

    // Create a new ETH stream (totalAmount comes from msg.value)
    function createStream(
        address recipient,
        uint256 startTime,
        uint256 endTime
    ) external payable returns (uint256 streamId);

    // Withdraw available funds from a stream
    function withdrawFromStream(uint256 streamId) external;

    // Check withdrawable amount
    function calculateWithdrawableAmount(
        uint256 streamId
    ) external view returns (uint256);
}

contract EthStreamer is IStreamingContractV1, Ownable {
    uint streamCounter;
    mapping(uint => Stream) public streams;

    constructor(address _owner) Ownable(_owner) {}

    function createStream(
        address recipient,
        uint256 startTime,
        uint256 endTime
    ) external payable override onlyOwner returns (uint256 streamId) {
        require(startTime < endTime, Streaming_InvalidStartTime());
        require(startTime >= block.timestamp, Streaming_InvalidStartTime());
        Stream memory stream = Stream({
            recipient: recipient,
            sender: msg.sender,
            startTime: startTime,
            endTime: endTime,
            totalAmount: msg.value,
            withdrawnAmount: 0
        });
        streamCounter += 1;
        streams[streamCounter] = stream;

        emit StreamCreated(
            streamCounter,
            msg.sender,
            recipient,
            msg.value,
            startTime,
            endTime
        );
        return streamCounter;
    }

    function withdrawFromStream(uint256 streamId) external override {
        Stream memory stream = streams[streamId];
        require(stream.sender != address(0), Streaming_StreamNotExist());
        uint256 amount = (block.timestamp - stream.startTime) /
            (stream.endTime - stream.startTime);
        if (amount > stream.totalAmount) amount = stream.totalAmount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function calculateWithdrawableAmount(
        uint256 streamId
    ) external view override returns (uint256) {
        Stream memory stream = streams[streamId];
        require(stream.sender != address(0), Streaming_StreamNotExist());

        return
            (block.timestamp - stream.startTime) /
            (stream.endTime - stream.startTime);
    }
}
