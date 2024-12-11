# LuckyBlock: Decentralized Multi-Winner Lottery System

## Overview
LuckyBlock is a decentralized, transparent, and verifiable lottery system built on the Stacks blockchain. It features multi-winner selection with proportional prize distribution and implements robust random number generation using blockchain properties for fairness and transparency.

## Features

### Core Functionality
- **Multi-Winner Support**: Configurable number of winners (up to 10) per lottery
- **Proportional Prize Distribution**: Automatic prize splitting among winners
- **Verifiable Randomness**: Transparent random number generation using block properties
- **Customizable Parameters**: Adjustable ticket prices, minimum players, and block confirmations

### Security Features
- **Tamper-Resistant**: Randomness derived from immutable blockchain properties
- **Fair Selection**: Unique winner selection with no duplicates
- **Transparent Process**: All lottery states and winner selections are publicly verifiable
- **Automated Payouts**: Direct prize distribution to winner wallets

## Technical Implementation

### Smart Contract Structure
```clarity
;; Main Data Structures
- Lotteries Map: Stores all lottery information
- Participant Tickets Map: Tracks ticket ownership
- Configuration Variables: Manages lottery parameters

;; Key Functions
- initialize-lottery: Start new lottery round
- buy-ticket: Purchase lottery tickets
- draw-winners: Select winners and distribute prizes
```

### Random Number Generation
The contract implements a secure random number generation system using:
- Block timestamps
- Sequential seed modification
- Multiple entropy sources

### Prize Distribution Algorithm
1. Base prize calculation: `total_pot / number_of_winners`
2. Remainder distribution to first winner
3. Automatic transfer to all winners

## Usage Guide

### For Players

1. **Participating in a Lottery**
```clarity
;; Check current ticket price
(contract-call? .luckyblock get-ticket-price)

;; Buy a ticket
(contract-call? .luckyblock buy-ticket)
```

2. **Checking Results**
```clarity
;; Get current lottery information
(contract-call? .luckyblock get-current-lottery)

;; Check your tickets
(contract-call? .luckyblock get-participant-tickets lottery-id tx-sender)
```

### For Administrators

1. **Lottery Management**
```clarity
;; Initialize new lottery
(contract-call? .luckyblock initialize-lottery)

;; Configure parameters
(contract-call? .luckyblock set-ticket-price new-price)
(contract-call? .luckyblock set-winner-count new-count)
(contract-call? .luckyblock set-min-players new-min)
```

2. **Drawing Winners**
```clarity
;; Execute winner selection
(contract-call? .luckyblock draw-winners)
```

## Security Considerations

### Random Number Generation
- Uses multiple sources of entropy
- Block-based randomness for transparency
- Sequential seed modification for unpredictability

### Limitations
- Maximum 50 participants per lottery
- Maximum 10 winners per draw
- Minimum block confirmation requirement

### Best Practices
- Regular parameter audits
- Monitoring of participant distribution
- Verification of random seed generation

## Contract Parameters

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| ticket-price | 1 STX | Cost per lottery ticket |
| min-players | 2 | Minimum participants required |
| min-blocks | 100 | Blocks before draw allowed |
| winner-count | 3 | Number of winners per lottery |

## Installation and Deployment

1. Clone the repository
```bash
git clone https://github.com/chiedozieobidile/luckyblock.git
```

2. Deploy the contract
```bash
clarinet contract deploy luckyblock
```

3. Initialize the contract
```clarity
(contract-call? .luckyblock initialize-lottery)
```

## Testing

Run the test suite:
```bash
clarinet test
```

Key test scenarios:
- Lottery initialization
- Ticket purchases
- Winner selection
- Prize distribution
- Error conditions

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to your branch
5. Create a Pull Request


## Support

For support and queries:
- Create an issue in the GitHub repository
- Contact the development team at [contact information]
- Join our community Discord server

## Disclaimer

This smart contract is provided as-is. Users should perform their own security audits before deployment or participation. The developers are not responsible for any losses incurred through the use of this contract.