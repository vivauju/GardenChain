# GardenChain

GardenChain is a decentralized community garden management system built on the Stacks blockchain. It enables transparent and fair administration of community garden plots through smart contracts.

## Features

- **Plot Reservation System**: Gardeners can reserve multiple plots by staking STX tokens
- **Seasonal Management**: Defined growing seasons with configurable parameters
- **Featured Gardener Program**: Random selection of featured gardeners at season end
- **Reward Distribution**: Automated distribution of harvest bonuses
- **Community Fund**: Percentage-based contribution to community development
- **Safety Mechanisms**: Built-in checks for fund safety and fair participation

## Smart Contract Functions

### Administrative Functions

- `start-growing-season`: Initialize a new growing season
- `end-growing-season`: Conclude the current growing season
- `cancel-growing-season`: Cancel an active season if minimum participation isn't met
- `collect-community-fund`: Withdraw accumulated community funds

### Gardener Functions

- `reserve-plots`: Reserve garden plots for the season
- `claim-harvest-bonus`: Claim rewards for featured gardeners
- `refund-gardener-fees`: Get refunds for unused plots
- `get-gardener-plots`: Check plot ownership

### Read-Only Functions

- `get-plot-fee`: View current plot reservation fee
- `get-garden-status`: Check current garden status
- `get-featured-gardener`: View the selected featured gardener
- `get-harvest-info`: Access harvest distribution information

## Technical Details

### Constants

- Minimum gardeners required: 5
- Maximum plots per gardener: 10
- Community fund rate: 5%
- Default plot reservation fee: 1 STX

### Error Codes

- `ERR-NOT-AUTHORIZED` (u100): Unauthorized access attempt
- `ERR-SEASON-CLOSED` (u101): Operation during closed season
- `ERR-SEASON-ACTIVE` (u102): Invalid operation during active season
- `ERR-INSUFFICIENT-FUNDS` (u103): Inadequate STX balance
- `ERR-NO-GARDENERS` (u104): Insufficient gardener participation
- `ERR-SEASON-ENDED` (u105): Operation after season end
- `ERR-INVALID-PARAMETER` (u106): Invalid input parameters
- `ERR-NOT-SELECTED` (u107): Unauthorized reward claim
- `ERR-ALREADY-DISTRIBUTED` (u108): Duplicate distribution attempt

## Security

The contract includes multiple safety checks:
- Admin-only access for sensitive functions
- Season state validation
- Balance verification
- Participation thresholds
- Distribution controls

## Getting Started

1. Deploy the smart contract to the Stacks blockchain
2. Set up initial parameters as the contract administrator
3. Open the growing season for plot reservations
4. Monitor participation and manage seasonal transitions

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
