// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

pragma solidity 0.8.26;

interface IStreamingContractV1 {
    struct Stream {
        address recipient;
        address sender;
        uint256 startTime;
        uint256 endTime;
        uint256 totalAmount;
        uint256 withdrawnAmount;
        address tokenAddress;
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
    error Streaming_NotSender();
    error Streaming_AlreadyCancelled();
    error Streaming_NotNftOwner();
    error Streaming_NothingToWithraw();

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
    function calculateWithdrawableAmount(
        uint256 streamId
    ) external view returns (uint256);

    // Cancel a stream (only sender can call)
    function cancelStream(uint256 streamId) external;
}

contract EthStremer is
    IStreamingContractV1,
    Ownable,
    ReentrancyGuard,
    ERC721Enumerable
{
    uint256 public streamCounter;
    mapping(uint256 => Stream) public streams;

    constructor(
        address _owner
    ) ERC721("Streaming Payroll NFT", "STREAM") Ownable(_owner) {}

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

        uint256 totalAmount;
        if (tokenAddress == address(0)) {
            totalAmount = msg.value;
        } else {
            totalAmount = IERC20(tokenAddress).allowance(
                msg.sender,
                address(this)
            );
            require(totalAmount > 0, "Token amount not approved");
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                totalAmount
            );
        }

        streamCounter += 1;
        streamId = streamCounter;

        streams[streamId] = Stream({
            sender: msg.sender,
            tokenAddress: tokenAddress,
            startTime: startTime,
            endTime: endTime,
            totalAmount: totalAmount,
            withdrawnAmount: 0,
            cancelled: false
        });

        _safeMint(recipient, streamId);

        emit StreamCreated(
            streamId,
            msg.sender,
            recipient,
            totalAmount,
            startTime,
            endTime
        );
    }

    function calculateWithdrawableAmount(
        uint256 streamId
    ) public view streamExists(streamId) returns (uint256) {
        Stream storage stream = streams[streamId];
        if (block.timestamp < stream.startTime || stream.cancelled) {
            return 0;
        }

        uint256 elapsed = block.timestamp > stream.endTime
            ? stream.endTime - stream.startTime
            : block.timestamp - stream.startTime;

        uint256 totalDuration = stream.endTime - stream.startTime;
        uint256 unlocked = (stream.totalAmount * elapsed) / totalDuration;

        if (unlocked < stream.withdrawnAmount) return 0;
        return unlocked - stream.withdrawnAmount;
    }

    function withdrawFromStream(
        uint256 streamId
    ) external nonReentrant streamExists(streamId) {
        require(ownerOf(streamId) == msg.sender, Streaming_NotNftOwner());

        uint256 amount = calculateWithdrawableAmount(streamId);
        require(amount > 0, Streaming_NothingToWithraw());

        streams[streamId].withdrawnAmount += amount;

        address token = streams[streamId].tokenAddress;
        if (token == address(0)) {
            (bool sent, ) = msg.sender.call{value: amount}("");
            require(sent, "ETH transfer failed");
        } else {
            IERC20(token).transfer(msg.sender, amount);
        }

        emit Withdrawal(streamId, msg.sender, amount);
    }

    function cancelStream(
        uint256 streamId
    ) external nonReentrant streamExists(streamId) {
        Stream storage stream = streams[streamId];
        if (msg.sender != stream.sender) revert Streaming_NotSender();
        if (stream.cancelled) revert Streaming_AlreadyCancelled();

        address recipient = ownerOf(streamId);
        uint256 withdrawable = calculateWithdrawableAmount(streamId);
        uint256 remaining = stream.totalAmount -
            stream.withdrawnAmount -
            withdrawable;

        stream.withdrawnAmount = stream.totalAmount;
        stream.cancelled = true;

        if (withdrawable > 0) {
            if (stream.tokenAddress == address(0)) {
                (bool sent, ) = recipient.call{value: withdrawable}("");
                require(sent, "ETH to recipient failed");
            } else {
                IERC20(stream.tokenAddress).transfer(recipient, withdrawable);
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

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
