# Ethereum Streaming Payroll

A smart contract system for **streaming payments** over time, supporting both **ETH and ERC-20 tokens**, with optional cancellation and NFT ownership-based claim rights. This contract is designed for payroll-like use cases, where funds unlock gradually between a `startTime` and `endTime`.

## Features

- **Streaming Payments**  
  Continuous fund release from sender to recipient over a time window.
  
- **ETH and ERC-20 Support**  
  Supports both native ETH and any ERC-20 token with allowance-based deposits.

- **NFT Ownership = Claim Rights**  
  Each stream is represented by an NFT, and only the NFT holder can withdraw from the stream.

- **Cancelable Streams**  
  Sender can cancel a stream mid-way. Remaining funds are split between the recipient (earned) and sender (unearned).

- **Reentrancy Guard**  
  Withdrawals and cancellations are protected against reentrancy attacks.

## Technical Overview

- `createStream(...)`: Initializes a stream with ETH or ERC-20 funds.
- `withdrawFromStream(...)`: Allows the NFT holder to claim unlocked funds.
- `cancelStream(...)`: Lets the sender cancel and reclaim unused funds.
- `calculateWithdrawableAmount(...)`: View-only method for unlocked balance.

Each stream is uniquely identified by an ID and is linked to an ERC-721 token (`Streaming Payroll NFT`).

## Testing

The contract is tested with [Foundry](https://book.getfoundry.sh/) and includes full test coverage for:

- ETH and ERC-20 stream creation
- Time-based fund unlocking
- Withdrawals and NFT access control
- Stream cancellation logic
- Revert cases and edge conditions

To run tests:

```bash
forge test -vvv
```
