# 🪙 PeerLend - Peer-to-Peer Bitcoin Lending

> A non-custodial platform for lending and borrowing Bitcoin with on-chain collateral using Clarity smart contracts for trustless execution.

## 📋 Overview

PeerLend enables trustless Bitcoin lending through smart contracts on the Stacks blockchain. Borrowers can request loans by posting collateral, while lenders can fund these requests and earn interest. The entire process is automated through smart contracts, ensuring transparency and security.

## 🚀 Features

- 💰 **Non-custodial lending** - Users maintain control of their funds
- 🔒 **Collateralized loans** - All loans require STX collateral 
- ⚡ **Automated liquidation** - Expired loans trigger automatic collateral liquidation
- 🔄 **Loan refinancing** - Borrowers can refinance active loans with better terms from competing lenders
- 📊 **Configurable parameters** - Adjustable interest rates, collateral ratios, and loan durations
- 💸 **Platform fees** - Built-in fee mechanism for protocol sustainability
- 🔍 **Full transparency** - All loan data stored on-chain and publicly accessible

## 🏗️ Contract Functions

### 📊 Core Lending Functions

- `create-loan-request(amount, collateral, interest-rate, duration)` - Create a new loan request
- `fund-loan(loan-id)` - Fund an existing loan request
- `repay-loan(loan-id)` - Repay an active loan with interest
- `liquidate-loan(loan-id)` - Liquidate an expired loan
- `cancel-loan-request(loan-id)` - Cancel a pending loan request

### 🔄 Loan Refinancing Functions

- `create-refinance-request(loan-id, requested-rate, requested-duration)` - Request refinancing for an active loan
- `submit-refinance-offer(refinance-id, offered-rate, offered-duration)` - Submit a competitive refinancing offer
- `accept-refinance-offer(refinance-id, chosen-lender)` - Accept a refinancing offer and execute the transfer
- `cancel-refinance-request(refinance-id)` - Cancel a pending refinancing request

### 💳 Balance Management

- `deposit-funds(amount)` - Deposit STX for lending
- `withdraw-funds(amount)` - Withdraw available STX balance
- `deposit-collateral(amount)` - Deposit STX as loan collateral
- `withdraw-collateral(amount)` - Withdraw unused collateral

### 👀 Read-Only Functions

- `get-loan(loan-id)` - Get loan details
- `get-user-balance(user)` - Check user's lending balance
- `get-user-collateral(user)` - Check user's collateral balance
- `calculate-total-repayment(loan-id)` - Calculate total repayment amount
- `get-refinance-request(refinance-id)` - Get refinancing request details
- `get-refinance-offer(refinance-id, lender)` - Get specific refinancing offer
- `get-next-refinance-id()` - Get next available refinancing request ID

## 📖 Usage Guide

### For Borrowers 💸

1. **Deposit Collateral**
   ```clarity
   (contract-call? .PeerLend deposit-collateral u1500000) ;; 1.5 STX collateral
   ```

2. **Create Loan Request**
   ```clarity
   (contract-call? .PeerLend create-loan-request 
     u1000000  ;; 1 STX loan amount
     u1500000  ;; 1.5 STX collateral 
     u1000     ;; 10% interest rate (basis points)
     u1000)    ;; 1000 blocks duration
   ```

3. **Repay Loan** (after funding)
   ```clarity
   (contract-call? .PeerLend repay-loan u1) ;; Repay loan ID 1
   ```

### For Lenders 🏦

1. **Deposit Funds**
   ```clarity
   (contract-call? .PeerLend deposit-funds u2000000) ;; 2 STX for lending
   ```

2. **Fund a Loan**
   ```clarity
   (contract-call? .PeerLend fund-loan u1) ;; Fund loan ID 1
   ```

3. **Submit Refinancing Offer**
   ```clarity
   (contract-call? .PeerLend submit-refinance-offer 
     u1       ;; refinance request ID
     u800     ;; 8% interest rate (lower than original)
     u1200)   ;; 1200 blocks duration
   ```

4. **Liquidate Expired Loan** (if applicable)
   ```clarity
   (contract-call? .PeerLend liquidate-loan u1) ;; Liquidate loan ID 1
   ```

### For Refinancing 🔄

1. **Create Refinancing Request** (borrower)
   ```clarity
   (contract-call? .PeerLend create-refinance-request
     u1       ;; loan ID to refinance
     u800     ;; desired 8% interest rate  
     u1500)   ;; desired 1500 blocks duration
   ```

2. **Accept Refinancing Offer** (borrower)
   ```clarity
   (contract-call? .PeerLend accept-refinance-offer
     u1                     ;; refinance request ID
     'ST1REFINANCE-LENDER)  ;; chosen lender's address
   ```

3. **Cancel Refinancing Request** (borrower)
   ```clarity
   (contract-call? .PeerLend cancel-refinance-request u1) ;; Cancel refinance ID 1
   ```

## ⚙️ Configuration

### Default Parameters

- **Minimum Collateral Ratio**: 150% (borrower must post 1.5x collateral)
- **Platform Fee**: 2.5% (250 basis points)
- **Interest Rates**: Set by borrowers when creating loan requests
- **Loan Duration**: Set by borrowers (in blocks)

### Admin Functions 👨‍💼

Contract owner can adjust:
- `set-platform-fee-rate(new-rate)` - Update platform fee percentage
- `set-min-collateral-ratio(new-ratio)` - Update minimum collateral requirement

## 🔐 Security Features

- ✅ **Collateral validation** - Ensures sufficient collateral before loan creation
- ✅ **Authorization checks** - Only loan participants can perform actions
- ✅ **Expiration handling** - Automatic liquidation for expired loans
- ✅ **Balance verification** - Prevents overdrafts and insufficient funds
- ✅ **Status tracking** - Comprehensive loan state management

## 📊 Loan States

### Core Loan States
- `pending` - Loan request created, awaiting funding
- `active` - Loan funded, repayment period active
- `repaid` - Loan successfully repaid by borrower
- `liquidated` - Loan expired and collateral seized
- `cancelled` - Loan request cancelled by borrower

### Refinancing States
- `open` - Refinancing request created, accepting offers
- `executed` - Refinancing completed successfully
- `cancelled` - Refinancing request cancelled by borrower

## 🧮 Interest Calculation

Interest is calculated using the formula:
```
Interest = (Principal × Rate × Duration) ÷ 10000
```

Where:
- **Principal**: Loan amount in microSTX
- **Rate**: Interest rate in basis points (e.g., 1000 = 10%)
- **Duration**: Loan duration in blocks

## 🚀 Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/markussamuel087/Peer-to-Peer-Bitcoin-Lending.git
   cd Peer-to-Peer-Bitcoin-Lending
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Test the contract**
   ```bash
   clarinet test
   ```

4. **Deploy locally**
   ```bash
   clarinet integrate
   ```

## 📄 License

MIT License - see LICENSE file for details.

---

Built with ❤️ using [Clarity](https://docs.stacks.co/docs/clarity/) and [Clarinet](https://github.com/hirosystems/clarinet)
