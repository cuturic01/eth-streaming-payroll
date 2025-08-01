// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract EthStreamer is Ownable, ReentrancyGuard {
    struct Stream {
        address recipient;
        address sender;
        address tokenAddress; // address(0) for ETH
        uint256 startTime;
        uint256 endTime;
        uint256 totalAmount;
        uint256 withdrawnAmount;
        bool cancelled;
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

    event StreamCancelled(
        uint256 indexed streamId,
        uint256 recipientBalance,
        uint256 senderBalance
    );

    error Streaming_InvalidStartTime();
    error Streaming_StreamNotExist();
    error Streaming_NotRecipient();
    error Streaming_NotSender();
    error Streaming_AlreadyCancelled();

    uint256 public streamCounter;
    mapping(uint256 => Stream) public streams;

    constructor(address _owner) Ownable(_owner) {}

    modifier streamExists(uint256 streamId) {
        if (streams[streamId].sender == address(0)) {
            revert Streaming_StreamNotExist();
        }
        _;
    }

    function createStream(
        address recipient,
        address tokenAddress,
        uint256 startTime,
        uint256 endTime
    ) external payable onlyOwner returns (uint256 streamId) {
        if (startTime < block.timestamp || endTime <= startTime) {
            revert Streaming_InvalidStartTime();
        }

        uint256 totalAmount = tokenAddress == address(0) ? msg.value : 0;
        if (tokenAddress != address(0)) {
            totalAmount = IERC20(tokenAddress).allowance(msg.sender, address(this));
            require(totalAmount > 0, "Token amount not approved");
            IERC20(tokenAddress).transferFrom(msg.sender, address(this), totalAmount);
        }

        streamCounter += 1;
        streams[streamCounter] = Stream({
            recipient: recipient,
            sender: msg.sender,
            tokenAddress: tokenAddress,
            startTime: startTime,
            endTime: endTime,
            totalAmount: totalAmount,
            withdrawnAmount: 0,
            cancelled: false
        });

        emit StreamCreated(streamCounter, msg.sender, recipient, totalAmount, startTime, endTime);
        return streamCounter;
    }

    function calculateWithdrawableAmount(uint256 streamId)
        public
        view
        streamExists(streamId)
        returns (uint256)
    {
        Stream storage stream = streams[streamId];
        if (block.timestamp < stream.startTime || stream.cancelled) {
            return 0;
        }

        uint256 elapsed = block.timestamp > stream.endTime
            ? stream.endTime - stream.startTime
            : block.timestamp - stream.startTime;

        uint256 totalDuration = stream.endTime - stream.startTime;
        uint256 unlockedAmount = (stream.totalAmount * elapsed) / totalDuration;

        if (unlockedAmount < stream.withdrawnAmount) return 0;
        return unlockedAmount - stream.withdrawnAmount;
    }

    function withdrawFromStream(uint256 streamId) external nonReentrant streamExists(streamId) {
        Stream storage stream = streams[streamId];
        if (stream.recipient != msg.sender) revert Streaming_NotRecipient();

        uint256 amount = calculateWithdrawableAmount(streamId);
        require(amount > 0, "Nothing to withdraw");

        stream.withdrawnAmount += amount;

        if (stream.tokenAddress == address(0)) {
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(stream.tokenAddress).transfer(msg.sender, amount);
        }

        emit Withdrawal(streamId, msg.sender, amount);
    }

    function cancelStream(uint256 streamId) external streamExists(streamId) nonReentrant {
        Stream storage stream = streams[streamId];
        if (stream.sender != msg.sender) revert Streaming_NotSender();
        if (stream.cancelled) revert Streaming_AlreadyCancelled();

        uint256 withdrawable = calculateWithdrawableAmount(streamId);
        uint256 remaining = stream.totalAmount - stream.withdrawnAmount - withdrawable;

        stream.cancelled = true;
        stream.withdrawnAmount = stream.totalAmount;

        if (withdrawable > 0) {
            if (stream.tokenAddress == address(0)) {
                (bool sent, ) = stream.recipient.call{value: withdrawable}("");
                require(sent, "ETH to recipient failed");
            } else {
                IERC20(stream.tokenAddress).transfer(stream.recipient, withdrawable);
            }
        }

        if (remaining > 0) {
            if (stream.tokenAddress == address(0)) {
                (bool sent, ) = stream.sender.call{value: remaining}("");
                require(sent, "ETH to sender failed");
            } else {
                IERC20(stream.tokenAddress).transfer(stream.sender, remaining);
            }
        }

        emit StreamCancelled(streamId, withdrawable, remaining);
    }
}
