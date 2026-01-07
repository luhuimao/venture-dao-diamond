# Venture DAO Diamond - Foundry Tests & Deployment

## 概述

使用Foundry测试和部署Diamond模式的Venture DAO。

---

## 安装Foundry

```bash
# 安装Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 初始化（如果需要）
forge init --force
```

---

## 项目设置

### 1. 安装依赖

```bash
# 安装forge-std
forge install foundry-rs/forge-std --no-commit

# 更新依赖
forge update
```

### 2. 编译合约

```bash
forge build
```

---

## 测试

### 运行所有测试

```bash
forge test
```

### 运行特定测试

```bash
# 运行Diamond测试
forge test --match-contract DiamondTest

# 运行特定函数
forge test --match-test testDiamondCreation

# 显示详细输出
forge test -vvv

# 显示gas报告
forge test --gas-report
```

### Gas Benchmark测试

```bash
# 运行gas benchmark
forge test --match-test testGas_ --gas-report
```

### 测试覆盖率

```bash
forge coverage
```

---

## 部署

### 1. 设置环境变量

创建 `.env` 文件：

```bash
# Private key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# RPC URLs
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_api_key
MAINNET_RPC_URL=https://mainnet.infura.io/v3/your_api_key

# Etherscan API Key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

加载环境变量：

```bash
source .env
```

### 2. 部署到本地网络

```bash
# 启动Anvil本地节点
anvil

# 在新终端部署
forge script script/foundry/DeployDiamond.s.sol:DeployDiamond \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### 3. 部署到测试网 (Sepolia)

```bash
forge script script/foundry/DeployDiamond.s.sol:DeployDiamond \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### 4. 创建DAO

```bash
# 确保先部署了factory
forge script script/foundry/CreateDAO.s.sol:CreateDAO \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

---

## 部署产物

部署完成后，地址将保存在 `./deployments/` 目录：

- `diamond-deployment.json` - Factory和所有Facets地址
- `dao-{address}.json` - 每个创建的DAO信息

---

## 验证合约

### 单独验证

```bash
forge verify-contract \
  --chain-id 11155111 \
  --constructor-args $(cast abi-encode "constructor()") \
  <CONTRACT_ADDRESS> \
  contracts/diamond/DAOFactory.sol:DAOFactory \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### 自动验证（部署时）

在部署命令中添加 `--verify`：

```bash
forge script script/foundry/DeployDiamond.s.sol:DeployDiamond \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

---

## 交互示例

### 使用cast与合约交互

```bash
# 设置DAO地址
DAO_ADDRESS=0x...

# 查询DAO名称
cast call $DAO_ADDRESS "daoName()(string)" --rpc-url $SEPOLIA_RPC_URL

# 注册成员（需要owner权限）
cast send $DAO_ADDRESS \
  "registerMember(address,uint256)" \
  0x1234567890123456789012345678901234567890 \
  100 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 查询成员信息
cast call $DAO_ADDRESS \
  "isMember(address)(bool)" \
  0x1234567890123456789012345678901234567890 \
  --rpc-url $SEPOLIA_RPC_URL

# 获取所有facets
cast call $DAO_ADDRESS "facets()(tuple[])" --rpc-url $SEPOLIA_RPC_URL
```

---

## 升级Diamond

### 1. 部署新Facet

```bash
# 部署新版本的GovernanceFacet
forge create \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  contracts/diamond/facets/GovernanceFacet.sol:GovernanceFacet
```

### 2. 准备DiamondCut

创建升级脚本 `script/foundry/UpgradeDAO.s.sol`:

```solidity
// 使用diamondCut替换facet
IDiamondCut(diamond).diamondCut(cuts, address(0), "");
```

### 3. 执行升级

```bash
forge script script/foundry/UpgradeDAO.s.sol:UpgradeDAO \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

---

## Gas优化检查

### 查看详细Gas使用

```bash
forge test --gas-report
```

### Snapshot对比

```bash
# 创建baseline
forge snapshot

# 修改代码后对比
forge snapshot --diff .gas-snapshot
```

---

## 调试

### 跟踪交易

```bash
# 详细输出 (-vvvv)
forge test --match-test testSubmitVote -vvvv

# 使用debugger
forge test --match-test testSubmitVote --debug
```

### 检查存储布局

```bash
forge inspect ConfigurationFacet storage-layout
```

---

## CI/CD集成

### GitHub Actions示例

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1
      
      - name: Run tests
        run: forge test
      
      - name: Gas report
        run: forge test --gas-report
```

---

## 常见问题

### Q: 编译错误 "Stack too deep"
A: 使用 `via_ir = true` 在 foundry.toml

### Q: 测试失败 "Insufficient balance"
A: 使用 `vm.deal(address, amount)` 给地址充值

### Q: 无法找到合约
A: 检查 `foundry.toml` 中的 `src` 路径配置

---

## 资源链接

- [Foundry Book](https://book.getfoundry.sh/)
- [Forge Std Reference](https://github.com/foundry-rs/forge-std)
- [EIP-2535 Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535)
- [Diamond Reference Implementation](https://github.com/mudgen/diamond)

---

## 文件结构

```
venture-dao/
├── contracts/diamond/       # Diamond合约
├── script/foundry/         # 部署脚本
│   ├── DeployDiamond.s.sol
│   └── CreateDAO.s.sol
├── test/foundry/          # 测试文件
│   └── Diamond.t.sol
├── deployments/           # 部署产物
├── foundry.toml          # Foundry配置
└── .env                  # 环境变量
```
