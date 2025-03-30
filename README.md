# STXSubscriptor

A Clarity smart contract for managing subscription services on the Stacks blockchain.

## Overview

STXSubscriptor is a decentralized subscription management system that enables vendors to offer subscription-based services while giving customers full control over their subscription plans. The contract handles subscription creation, periodic payments, and subscription management, all secured by the Stacks blockchain.

## Features

- **Vendor registration**: Approved vendors can offer subscription services through the platform
- **Subscription management**: Customers can subscribe to services with customizable duration and billing cycles
- **Automatic payments**: Periodic payments are processed securely through the contract
- **Cancellation options**: Customers can cancel subscriptions with transparent early termination fees
- **Admin controls**: Contract administrator can manage vendor approvals and global settings

## How It Works

1. Vendors must be approved by the contract administrator to offer services
2. Customers create subscriptions by specifying:
   - Vendor
   - Fee amount per billing cycle
   - Total duration
   - Billing cycle length
3. The full subscription cost is locked in the contract at subscription creation
4. Vendors can claim payments at each billing cycle
5. Customers can cancel subscriptions at any time (with potential early termination fees)

## Contract Functions

### Admin Functions

- `add-vendor`: Register a new service provider
- `deactivate-vendor`: Remove a service provider's authorization
- `update-minimum-period`: Set the minimum subscription period
- `transfer-admin-rights`: Transfer contract ownership to a new administrator

### Customer Functions

- `subscribe`: Create a new subscription with a vendor
- `cancel-subscription`: End an active subscription

### Vendor Functions

- `collect-payment`: Process a payment for a customer's subscription

### Read-Only Functions

- `is-approved-vendor`: Check if a principal is an authorized vendor
- `get-plan-details`: View details of a customer's subscription
- `get-minimum-subscription-period`: Get the minimum subscription period in days
- `get-admin`: Get the current contract administrator

## Error Codes

| Code | Description |
|------|-------------|
| u1   | Subscription not found |
| u2   | Subscription not active |
| u3   | Payment interval not reached |
| u4   | Subscription expired |
| u5   | Invalid amount (must be > 0) |
| u6   | Invalid duration (must be > 0) |
| u7   | Invalid interval (must be > 0) |
| u8   | Duration must be >= interval |
| u9   | Invalid minimum period (must be > 0) |
| u10  | Cannot transfer to current admin |
| u11  | Vendor cannot subscribe to itself |
| u13  | Vendor already registered |
| u14  | Vendor not found |
| u15  | Not an authorized vendor |
| u16  | Not the subscription vendor |
| u17  | Vendor not authorized |
| u18  | Subscription does not exist |
| u403 | Unauthorized, admin only |

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) for local development and testing
- Basic understanding of Clarity and Stacks blockchain

### Deployment

1. Clone this repository
2. Use Clarinet to test and deploy the contract

```bash
# Install Clarinet
curl -sL https://github.com/hirosystems/clarinet/releases/download/v1.0.0/clarinet-linux-x64-glibc.tar.gz -o clarinet.tar.gz
tar -xf clarinet.tar.gz
chmod +x ./clarinet
sudo mv ./clarinet /usr/local/bin

# Initialize a new Clarinet project
clarinet new stx-subscriptor
cd stx-subscriptor

# Add the contract
cp path/to/stx-subscriptor.clar contracts/

# Test the contract
clarinet test

# Deploy to testnet
clarinet deploy --testnet
```

## Use Cases

- SaaS products offering blockchain-based subscription options
- Content creator monetization
- Recurring membership fees for DAOs
- Periodic access to digital services
- Automated payment systems for ongoing services

## Security Considerations

- The contract uses STX locking to ensure payments
- Early termination penalties prevent subscription abuse
- Admin controls are protected with principal verification
- All transactions are validated with appropriate assertions

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request