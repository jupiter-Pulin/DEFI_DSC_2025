# Decentralized StableCoin Engine (DSCEngine)

> 一个无治理、无手续费、超额抵押、去中心化的稳定币系统，灵感来源于 MakerDAO，但仅支持 WETH 和 WBTC 作为抵押品。

## 🧠 项目概述

DSCEngine 是一个核心合约，支持通过抵押 WETH 或 WBTC 铸造去中心化稳定币（DSC）。目标是始终保持 1 DSC = $1 的锚定价格，同时维持系统过度抵押状态以确保稳定性。

### ⚙️ 关键特性

- **美元锚定（1 DSC = $1）**
- **完全去中心化（无治理）**
- **链上预言机支持（Chainlink）**
- **无手续费铸币 & 赎回**
- **超额抵押机制（最小健康因子为 1.0）**
- **清算机制支持清偿不健康仓位**

---

## 📦 合约结构

DSCEngine.sol
├─ 状态变量
├─ 构造函数
├─ 抵押与铸币函数
├─ 赎回与销毁函数
├─ 清算逻辑
├─ 健康因子计算
├─ 预言机集成（Chainlink）

---

## 🔐 合约安全

- ✅ 使用 OpenZeppelin 的 `ReentrancyGuard` 防止重入攻击。
- ✅ 多种 `modifier` 保证调用合法性。
- ✅ 使用 Chainlink 数据源检查价格。

---

## 💡 系统设计理念

1. **超额抵押：** 所有用户的抵押价值必须大于他们铸造的稳定币价值。
2. **抵押率限制：** 初始抵押率需 ≥ 200%。
3. **清算激励：** 清算者可获得额外奖励（默认 10%）。
4. **健康因子（Health Factor）：** 衡量账户健康状况的指标，低于 1 将面临清算。

---

## 🔨 核心函数

### ✅ `depositCollateralizedAndMintDSC(...)`
存入抵押品并铸造 DSC。

### ✅ `redeemCollateralizedAndBurnDSC(...)`
销毁 DSC 并赎回相应数量的抵押品。

### ✅ `liquidate(...)`
当用户健康因子过低时，清算其仓位，获得抵押品+奖励。

### ✅ `getAccountInformation(...)`
获取用户当前债务及抵押品总价值。

---

## 🧪 示例：清算过程


初始状态：

用户抵押：1 ETH（$4000）

铸造：2000 DSC

价格变动：

ETH/USD 降至 $3000

抵押价值变为 $3000

健康因子变为 1.5（低于要求）

清算操作：

清算者偿还 2000 DSC

获得约 0.7334 ETH 抵押品

包括约 10% 奖励（0.0667 ETH）

---

## 🔍 开发者提示

- 所有价格查询依赖于 Chainlink 预言机（需提供 token => priceFeed 映射）。
- Solidity 精度计算依赖于 `PRECISION = 1e18` 和 `ADDITIONAL_FEED_PRECISION = 1e10`。
- 所有合约调用需先通过 ERC20 的 `approve(...)`。

---

## 📁 依赖项

- Solidity >=0.8.19
- OpenZeppelin Contracts
- Chainlink Data Feeds

---

## 📜 许可证

MIT License
