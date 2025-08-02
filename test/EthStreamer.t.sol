// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../contracts/EthStreamer.sol";

contract MockERC20 is IERC20 {
    string public name = "MockToken";
    string public symbol = "MTK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    function totalSupply() external pure returns (uint256) {
        return 1e24;
    }

    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return balances[account];
    }

    function transfer(
        address to,
        uint256 amount
    ) external override returns (bool) {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        allowances[from][msg.sender] -= amount;
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }

    // test-only mint
    function mint(address to, uint256 amount) external {
        balances[to] += amount;
    }
}

contract EthStreamerTest is Test {
    EthStreamer streamer;
    MockERC20 token;

    address owner = address(0x1);
    address recipient = address(0x2);

    function setUp() public {
        vm.prank(owner);
        streamer = new EthStreamer(owner);

        token = new MockERC20();
        token.mint(owner, 1_000 ether);
        vm.deal(owner, 100 ether);
    }

    function testCreateETHStream() public {
        uint256 start = block.timestamp + 10;
        uint256 end = start + 100;

        vm.prank(owner);
        uint256 streamId = streamer.createStream{value: 10 ether}(
            recipient,
            address(0),
            start,
            end
        );

        (address r, address s, , , uint256 amt, , , ) = streamer.streams(
            streamId
        );
        assertEq(r, recipient);
        assertEq(s, owner);
        assertEq(amt, 10 ether);
        assertEq(streamer.ownerOf(streamId), recipient);
    }

    function testWithdrawETHStream() public {
        uint256 start = block.timestamp + 1;
        uint256 end = start + 100;

        vm.prank(owner);
        uint256 streamId = streamer.createStream{value: 10 ether}(
            recipient,
            address(0),
            start,
            end
        );

        vm.warp(start + 50);

        vm.prank(recipient);
        streamer.withdrawFromStream(streamId);

        assertEq(recipient.balance, 5 ether);
    }

    function testCreateAndWithdrawERC20Stream() public {
        uint256 start = block.timestamp + 5;
        uint256 end = start + 100;

        vm.prank(owner);
        token.approve(address(streamer), 100 ether);

        vm.prank(owner);
        uint256 streamId = streamer.createStream(
            recipient,
            address(token),
            start,
            end
        );

        vm.warp(start + 50);
        vm.prank(recipient);
        streamer.withdrawFromStream(streamId);

        assertEq(token.balanceOf(recipient), 50 ether);
    }

    function testCancelStreamETH() public {
        uint256 start = block.timestamp + 10;
        uint256 end = start + 100;

        vm.prank(owner);
        uint256 streamId = streamer.createStream{value: 10 ether}(
            recipient,
            address(0),
            start,
            end
        );

        vm.warp(start + 30);
        vm.prank(owner);
        streamer.cancelStream(streamId);

        assertGt(owner.balance, 0);
        assertGt(recipient.balance, 0);
    }

    function testRevertOnEarlyWithdraw() public {
        uint256 start = block.timestamp + 50;
        uint256 end = start + 100;

        vm.prank(owner);
        uint256 streamId = streamer.createStream{value: 1 ether}(
            recipient,
            address(0),
            start,
            end
        );

        vm.expectRevert();
        vm.prank(recipient);
        streamer.withdrawFromStream(streamId);
    }

    function testRevertOnUnauthorizedCancel() public {
        uint256 start = block.timestamp + 1;
        uint256 end = start + 100;

        vm.prank(owner);
        uint256 streamId = streamer.createStream{value: 1 ether}(
            recipient,
            address(0),
            start,
            end
        );

        vm.expectRevert(Streaming_NotSender.selector);
        vm.prank(address(0xBEEF));
        streamer.cancelStream(streamId);
    }

    function testRevertOnInvalidTimestamps() public {
        vm.warp(1000);
        uint256 start = block.timestamp - 100;
        uint256 end = start + 50;

        vm.expectRevert(Streaming_InvalidStartTime.selector);
        vm.prank(owner);
        streamer.createStream{value: 1 ether}(
            recipient,
            address(0),
            start,
            end
        );
    }
}
