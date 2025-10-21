# 📚 Decentralized Book Exchange

A peer-to-peer platform for lending and trading textbooks secured by smart contract escrow on the Stacks blockchain.

## 🌟 Features

- **📖 Book Listing**: List books for lending or selling with detailed metadata
- **🔒 Escrow Protection**: Secure transactions with automatic fund management  
- **⏰ Time-based Lending**: Set custom lending periods with automatic overdue handling
- **⭐ Reputation System**: Rate users to build community trust
- **🛡️ Dispute Resolution**: Built-in arbitration system for trade conflicts
- **💰 Platform Fees**: Minimal fees to sustain the platform

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- STX tokens for transactions

### Installation
```bash
git clone <repository-url>
cd Decentralized-Book-Exchange
clarinet check
```

## 📋 Usage

### Listing a Book
```clarity
(contract-call? .Decentralized-Book-Exchange list-book 
  "Calculus: Early Transcendentals" 
  "James Stewart" 
  "9781285741550" 
  "good" 
  "lend" 
  u500000)
```

### Initiating a Trade
```clarity
;; For lending (book-id u1, 30-day period)
(contract-call? .Decentralized-Book-Exchange initiate-trade u1 u30)

;; For buying (book-id u1, period ignored for sales)
(contract-call? .Decentralized-Book-Exchange initiate-trade u1 u0)
```

### Managing Trades
```clarity
;; Approve pending trade
(contract-call? .Decentralized-Book-Exchange approve-trade u1)

;; Return borrowed book
(contract-call? .Decentralized-Book-Exchange return-book u1)

;; Confirm return with rating (1-5 stars)
(contract-call? .Decentralized-Book-Exchange confirm-return u1 u5)
```

## 🔧 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `list-book` | 📝 List a book for lending or selling |
| `update-book-availability` | 🔄 Toggle book availability |
| `initiate-trade` | 🤝 Start a trade with escrow deposit |
| `approve-trade` | ✅ Accept incoming trade request |
| `reject-trade` | ❌ Decline trade and refund escrow |
| `return-book` | 📤 Mark book as returned (borrower) |
| `confirm-return` | ✅ Confirm return and rate user (lender) |
| `claim-overdue` | ⏰ Claim escrow for overdue books |
| `dispute-trade` | ⚖️ Initiate dispute resolution |
| `resolve-dispute` | 🏛️ Admin function to resolve disputes |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-book` | 📖 Get book details by ID |
| `get-trade` | 🤝 Get trade information |
| `get-user-rating` | ⭐ Get user reputation data |
| `get-platform-earnings` | 💰 View platform revenue |
| `get-books-by-owner` | 📚 List books owned by user |
| `is-trade-overdue` | ⏰ Check if trade is overdue |

## 💡 Trade Types

### 📚 Lending
- Temporary book access with return requirement
- Escrow includes book value + security deposit
- Time-limited with automatic overdue handling
- 10% lending fee on successful return

### 💰 Selling  
- Permanent ownership transfer
- Escrow equals book price
- Immediate completion upon approval
- Platform fee deducted from payment

## ⚡ Escrow System

- **Minimum Escrow**: 1 STX + book price for lending
- **Security Deposit**: Protects against non-return
- **Platform Fee**: 100 microSTX per transaction
- **Automatic Release**: Based on trade completion

## 🛡️ Safety Features

- ✅ Owner cannot trade with themselves
- ✅ Insufficient funds protection  
- ✅ Time-based lending limits (max 144 blocks)
- ✅ Status validation for all operations
- ✅ Admin dispute resolution

## 📊 Constants

```clarity
MIN-ESCROW-AMOUNT: 1,000,000 microSTX
MAX-LENDING-PERIOD: 144 blocks (~24 hours)
PLATFORM-FEE: 100 microSTX
```

## 🎯 Example Workflow

1. **📝 Alice lists** her calculus textbook for lending at 0.5 STX
2. **🤝 Bob initiates** a 30-day lending trade with 1.5 STX escrow
3. **✅ Alice approves** the trade request
4. **📚 Bob receives** the book for 30 days
5. **📤 Bob returns** the book after studying
6. **⭐ Alice confirms** return and rates Bob 5 stars
7. **💰 Bob receives** 1.35 STX back (minus 10% lending fee)
8. **🎉 Trade completed** successfully

## 🔒 Security Considerations

- All funds held in contract escrow until trade completion
- Reputation system encourages honest behavior
- Dispute resolution available for edge cases
- Time-based overdue protection for lenders

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is licensed under the MIT License.
