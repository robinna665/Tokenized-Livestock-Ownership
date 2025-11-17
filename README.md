# 🐄 Tokenized Livestock Ownership

A Clarity smart contract that enables fractional ownership of livestock through tokenized shares. Investors can buy shares in livestock, track expenses and revenue, and claim profits when the livestock is sold.

## 🚀 Features

- **Create Livestock** 🐮 - Register new livestock with defined share structure
- **Buy Shares** 💰 - Purchase fractional ownership in livestock
- **Track Expenses** 📊 - Record feeding, veterinary, and maintenance costs
- **Record Revenue** 💵 - Log income from milk, wool, or other products
- **Sell Livestock** 🏪 - Mark livestock as sold and finalize revenue
- **Claim Profits** 🎯 - Shareholders receive proportional profits after sale

## 📋 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `create-livestock` | Register new livestock for tokenization | `name`, `total-shares`, `price-per-share` |
| `buy-shares` | Purchase shares in livestock | `livestock-id`, `shares` |
| `add-expense` | Record livestock expenses (owner only) | `livestock-id`, `amount`, `description` |
| `add-revenue` | Record livestock revenue (owner only) | `livestock-id`, `amount` |
| `sell-livestock` | Mark livestock as sold (owner only) | `livestock-id`, `sale-price` |
| `claim-profits` | Claim proportional profits after sale | `livestock-id` |

### Read-Only Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `get-livestock` | Get livestock details | `livestock-id` |
| `get-shareholder-shares` | Get shareholder's share count | `livestock-id`, `shareholder` |
| `calculate-net-profit` | Calculate total profit for livestock | `livestock-id` |
| `calculate-shareholder-profit` | Calculate individual shareholder profit | `livestock-id`, `shareholder` |
| `get-available-shares` | Get remaining shares for purchase | `livestock-id` |

## 🛠️ Usage Example

### 1. Create Livestock
```clarity
(contract-call? .tokenized-livestock-ownership create-livestock "Bessie the Cow" u100 u1000)
```

### 2. Buy Shares
```clarity
(contract-call? .tokenized-livestock-ownership buy-shares u1 u10)
```

### 3. Add Expenses
```clarity
(contract-call? .tokenized-livestock-ownership add-expense u1 u500 "Veterinary checkup")
```

### 4. Record Revenue
```clarity
(contract-call? .tokenized-livestock-ownership add-revenue u1 u2000)
```

### 5. Sell Livestock
```clarity
(contract-call? .tokenized-livestock-ownership sell-livestock u1 u15000)
```

### 6. Claim Profits
```clarity
(contract-call? .tokenized-livestock-ownership claim-profits u1)
```

## 💡 How It Works

1. **Livestock Registration** 📝 - Owners create livestock entries with share structure
2. **Share Purchase** 🛒 - Investors buy fractional ownership using STX
3. **Expense Tracking** 📈 - All costs are recorded and tracked automatically
4. **Revenue Recording** 💰 - Income from livestock products is logged
5. **Profit Distribution** 🎁 - When sold, profits are distributed proportionally to shareholders

## 🔒 Security Features

- Owner-only functions for expense/revenue management
- Automatic profit calculation and distribution
- Share validation and availability checking
- Prevents double-claiming of profits

## 🚀 Getting Started

1. Deploy the contract to your Stacks network
2. Create livestock entries using `create-livestock`
3. Investors can buy shares with `buy-shares`
4. Track all expenses and revenue
5. Sell livestock and distribute profits automatically

## 📊 Profit Calculation

```
Net Profit = Total Revenue - Total Expenses
Shareholder Profit = (Net Profit × Shareholder Shares) ÷ Total Shares Sold
```

## 🎯 Use Cases

- **Cattle Investment** 🐄 - Fractional ownership in beef cattle
- **Dairy Operations** 🥛 - Share in milk production profits
- **Sheep Farming** 🐑 - Wool and meat revenue sharing
- **Poultry Business** 🐔 - Egg and meat production investments

---

*Built with ❤️ using Clarity smart contracts on Stacks blockchain*
```

**Git Commit Message:**
```
feat: implement tokenized livestock ownership with fractional shares and automated profit distribution
```

**GitHub Pull Request Title:**
```
🐄 Add Tokenized Livestock Ownership Smart Contract
```

**GitHub Pull Request Description:**
```
## 🐄 Tokenized Livestock Ownership Contract

This PR introduces a comprehensive smart contract for fractional livestock ownership with automated profit distribution.

### ✨ Features Added
- **Livestock Registration** - Create tokenized livestock with configurable share structure
- **Fractional Ownership** - Buy/sell shares in livestock using STX tokens
- **Expense Tracking** - Record and track all livestock-related costs
- **Revenue Management** - Log income from livestock products and sales
- **Automated Profit Distribution** - Proportional profit sharing among shareholders
- **Security Controls** - Owner-only functions and validation
