### Foundry DeFi Stablecoin

这是 Cyfrin Foundry Solidity 课程的一部分。

- [DSCEngine 示例](https://sepolia.etherscan.io/address/0x091ea0838ebd5b7dda2f2a641b068d6d59639b98#code)
- [去中心化稳定币示例](https://sepolia.etherscan.io/address/0xf30021646269007b0bdc0763fd736c6380602f2f#code)

---

### 关于

这个项目是一个稳定币系统，用户可以存入 WETH 和 WBTC，交换一个与 USD 锚定的代币。

- [Foundry DeFi Stablecoin](#foundry-defi-stablecoin)
- [关于](#about)
- [快速开始](#getting-started)
  - [要求](#requirements)
  - [快速启动](#quickstart)
  - [可选 Gitpod](#optional-gitpod)
- [更新](#updates)
- [使用](#usage)
  - [启动本地节点](#start-a-local-node)
  - [部署](#deploy)
  - [其他网络部署](#deploy---other-network)
  - [测试](#testing)
    - [测试覆盖率](#test-coverage)
- [部署到测试网或主网](#deployment-to-a-testnet-or-mainnet)
  - [脚本](#scripts)
  - [估算 Gas](#estimate-gas)
- [代码格式化](#formatting)
- [Slither](#slither)
- [附加信息](#additional-info)
  - [关于“官方”是什么意思](#lets-talk-about-what-official-means)
  - [总结](#summary)
- [感谢](#thank-you)

---

### 快速开始

#### 要求

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - 确保可以运行 `git --version`，并且能够看到类似 `git version x.x.x` 的响应。
- [foundry](https://getfoundry.sh/)
  - 确保可以运行 `forge --version`，并且能够看到类似 `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)` 的响应。

#### 快速启动

```bash
git clone https://github.com/Cyfrin/foundry-defi-stablecoin-cucd foundry-defi-stablecoin-cu
forge build
```

#### 可选 Gitpod

如果你不能或不想在本地安装和运行，可以选择在 Gitpod 上使用这个仓库。这样，你可以跳过 `clone this repo` 部分。

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#github.com/PatrickAlphaC/foundry-smart-contract-lottery-cu)

---

### 更新

- 最新版本的 `openzeppelin-contracts` 在 `ERC20Mock` 文件中有一些更改。为了跟随课程，您需要安装版本 4.8.3，可以通过以下命令安装：

  ```bash
  forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit
  ```

  而不是：

  ```bash
  forge install openzeppelin/openzeppelin-contracts --no-commit
  ```

---

### 使用

#### 启动本地节点

```bash
make anvil
```

#### 部署

这将默认部署到本地节点。你需要在另一个终端窗口运行该节点，以便它能够进行部署。

```bash
make deploy
```

#### 其他网络部署

[查看下面的测试网或主网部署说明](#deployment-to-a-testnet-or-mainnet)

#### 测试

我们在视频中讲解了 4 个测试层级：

1. 单元测试
2. 集成测试
3. 分叉测试
4. 阶段测试

在本仓库中，我们覆盖了第 1 类单元测试和模糊测试。

```bash
forge test
```

##### 测试覆盖率

```bash
forge coverage
```

覆盖率测试：

```bash
forge coverage --report debug
```

---

### 部署到测试网或主网

1. **设置环境变量**  
   你需要将 `SEPOLIA_RPC_URL` 和 `PRIVATE_KEY` 设置为环境变量。你可以将它们添加到 `.env` 文件中，格式与 `.env.example` 相似。

   - `PRIVATE_KEY`: 你的账户私钥（例如从 [MetaMask](https://metamask.io/)）。**注意：开发时请使用一个没有真实资金的账户私钥**。
     - [如何导出私钥](https://metamask.zendesk.com/hc/en-us/articles/360015289632-How-to-Export-an-Account-Private-Key)
   - `SEPOLIA_RPC_URL`: 这是你使用的 Sepolia 测试网节点的 URL。你可以从 [Alchemy](https://alchemy.com/?a=673c802981) 免费获得一个。
   - 可选：如果你想在 [Etherscan](https://etherscan.io/) 上验证你的合约，可以添加 `ETHERSCAN_API_KEY`。

2. **获取测试网 ETH**  
   访问 [faucets.chain.link](https://faucets.chain.link/) 获取一些测试网 ETH，并确保它们出现在你的 MetaMask 中。

3. **部署**

```bash
make deploy ARGS="--network sepolia"
```

---

### 脚本

你可以直接使用 `cast` 命令与合约交互，而不需要编写单独的脚本。

例如，在 Sepolia 测试网上：

1. **获取 WETH**

```bash
cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "deposit()" --value 0.1ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

2. **批准 WETH**

```bash
cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "approve(address,uint256)" 0x091EA0838eBD5b7ddA2F2A641B068d6D59639b98 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

3. **存入并铸造 DSC**

```bash
cast send 0x091EA0838eBD5b7ddA2F2A641B068d6D59639b98 "depositCollateralAndMintDsc(address,uint256,uint256)" 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 100000000000000000 10000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

---

### 估算 Gas

你可以通过运行以下命令来估算 Gas 消耗：

```bash
forge snapshot
```

你将看到一个名为 `.gas-snapshot` 的输出文件。

---

### 代码格式化

运行代码格式化：

```bash
forge fmt
```

---

### Slither

```bash
slither . --config-file slither.config.json
```

---

### 附加信息

一些用户曾经困惑 `Chainlink-brownie-contracts` 是否为官方的 Chainlink 仓库。以下是相关信息：

`Chainlink-brownie-contracts` 是官方的仓库。该仓库由 Chainlink 团队拥有和维护，且会按照正式的 Chainlink 发布流程进行发布。你可以看到它仍然位于 `smartcontractkit` 组织下。

[Chainlink-brownie-contracts GitHub 仓库](https://github.com/smartcontractkit/chainlink-brownie-contracts)

#### 关于“官方”是什么意思

“官方”发布流程是 Chainlink 将其包发布到 [npm](https://www.npmjs.com/package/@chainlink/contracts)。因此，直接从 `smartcontractkit/chainlink` 下载是错误的，因为它可能包含未发布的代码。

因此，你有两个选择：

1. 从 NPM 下载并将其作为 Foundry 的外部依赖。
2. 从 `chainlink-brownie-contracts` 仓库下载，它已经从 NPM 下载并将其打包，便于你在 Foundry 中使用。

---

### 总结

1. `chainlink-brownie-contracts` 是由 Chainlink 团队维护的官方仓库。
2. 它会按照 Chainlink 的正式发布周期（使用 npm）进行打包，便于在 Foundry 中使用。

---

