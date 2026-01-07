#!/bin/bash

# Diamond DAO - 快速验证脚本
# 用于验证Diamond合约编译和基本功能

set -e

echo "========================================="
echo "Diamond DAO 快速验证"
echo "========================================="
echo ""

# 1. 检查Foundry
echo "📌 步骤 1/4: 检查Foundry安装..."
if ! command -v forge &> /dev/null; then
    echo "❌ Forge未安装. 请安装Foundry: https://getfoundry.sh/"
    exit 1
fi
echo "✅ Foundry已安装: $(forge --version | head -n 1)"
echo ""

# 2. 编译Diamond合约
echo "📌 步骤 2/4: 编译Diamond合约..."
echo "执行: forge build "
if forge build  > /tmp/diamond-build.log 2>&1; then
    echo "✅ Diamond合约编译成功!"
else
    echo "❌ 编译失败. 查看日志: /tmp/diamond-build.log"
    cat /tmp/diamond-build.log
    exit 1
fi
echo ""

# 3. 检查生成的artifacts
echo "📌 步骤 3/4: 检查编译产物..."
ARTIFACTS=(
    "out/Diamond.sol/Diamond.json"
    "out/DAOFactory.sol/DAOFactory.json"
    "out/DiamondCutFacet.sol/DiamondCutFacet.json"
    "out/DiamondLoupeFacet.sol/DiamondLoupeFacet.json"
    "out/ConfigurationFacet.sol/ConfigurationFacet.json"
    "out/MembershipFacet.sol/MembershipFacet.json"
    "out/ProposalFacet.sol/ProposalFacet.json"
    "out/GovernanceFacet.sol/GovernanceFacet.json"
    "out/FundingFacet.sol/FundingFacet.json"
)

for artifact in "${ARTIFACTS[@]}"; do
    if [ -f "$artifact" ]; then
        echo "  ✓ $artifact"
    else
        echo "  ✗ $artifact (未找到)"
    fi
done
echo ""

# 4. 列出合约信息
echo "📌 步骤 4/4: 合约信息..."
echo ""
echo "核心合约:"
echo "  • Diamond Proxy"
echo "  • DAOFactory"
echo ""
echo "核心Facets (3):"
echo "  • DiamondCutFacet"
echo "  • DiamondLoupeFacet"
echo "  • OwnershipFacet"
echo ""
echo "业务Facets (5):"
echo "  • ConfigurationFacet"
echo "  • MembershipFacet"
echo "  • ProposalFacet"
echo "  • GovernanceFacet"
echo "  • FundingFacet"
echo ""

echo "========================================="
echo "✨ 验证完成!"
echo "========================================="
echo ""
echo "下一步:"
echo "  1. 运行测试: forge test --match-contract DiamondTest"

forge test --match-contract DiamondTest

echo "  2. 启动Anvil: anvil"
echo "  3. 部署: forge script script/foundry/DeployDiamond.s.sol --broadcast"
echo ""
forge test --match-contract DiamondTest