# Diamond DAO Gas优化

## 🎯 立即可实施的优化（高ROI）

### 优化#1: DAOFactory Selector缓存

**影响**: 每次创建DAO节省 ~2000 gas  

**实施方法**:

1. 在`DAOFactory.sol`顶部添加constants:
```solidity
// Configuration Facet Selectors
bytes4 private constant SEL_SET_CONFIG = bytes4(keccak256("setConfiguration(bytes32,uint256)"));
bytes4 private constant SEL_GET_CONFIG = bytes4(keccak256("getConfiguration(bytes32)"));
bytes4 private constant SEL_SET_ADDR_CONFIG = bytes4(keccak256("setAddressConfiguration(bytes32,address)"));
// ... 添加所有selectors
```

2. 在`_installBusinessFacets`中使用:
```solidity
configSelectors[0] = SEL_SET_CONFIG;
configSelectors[1] = SEL_GET_CONFIG;
// ...
```

---

### 优化#2: Storage Struct Packing

**影响**: 每个成员节省 ~15000 gas，每个提案节省~60000 gas  

**Member Struct优化**:
```solidity
// 在 LibDAOStorage.sol
struct Member {
    bool exists;          // 1 byte
    bool isSteward;       // 1 byte
    uint64 joinedAt;      // 8 bytes (够用到2554年)
    uint184 shares;       // 23 bytes
}
// 从 3 slots → 1 slot
```

**Proposal Struct优化**:
```solidity
struct Proposal {
    bytes32 id;                // 32 bytes - slot 0
    address proposer;          // 20 bytes - slot 1 (0-19)
    uint64 createdAt;          // 8 bytes  - slot 1 (20-27)
    ProposalStatus status;     // 1 byte   - slot 1 (28)
    ProposalType proposalType; // 1 byte   - slot 1 (29)
    uint64 votingEndTime;      // 8 bytes  - slot 2 (0-7)
    uint96 yesVotes;           // 12 bytes - slot 2 (8-19)
    uint96 noVotes;            // 12 bytes - slot 2 (20-31)
}
// 从 7 slots → 3 slots
```

---

### 优化#3: VotingPower缓存

**影响**: 每次投票处理节省 ~5000 gas  

**实施方法**:

1. 在`LibDAOStorage.DAOStorage`添加:
```solidity
uint256 totalVotingPower;
```

2. 在`MembershipFacet._registerMember`中:
```solidity
ds.totalVotingPower += (shares == 0 ? 1 : shares);
```

3. 在`MembershipFacet.updateShares`中:
```solidity
uint256 oldPower = (ds.members[member].shares == 0 ? 1 : ds.members[member].shares);
uint256 newPower = (newShares == 0 ? 1 : newShares);
ds.totalVotingPower = ds.totalVotingPower - oldPower + newPower;
```

4. 在`GovernanceFacet._getTotalVotingPower`中:
```solidity
function _getTotalVotingPower() internal view returns (uint256) {
    return LibDAOStorage.daoStorage().totalVotingPower;
}
```

---

### 优化#4: Custom Errors

**影响**: 每次revert节省 ~50 gas  

**实施方法**:

1. 在各facet顶部定义errors:
```solidity
// MembershipFacet.sol
error InvalidAddress();
error MemberExists();
error NotAMember();
error AlreadySteward();
```

2. 替换requires:
```solidity
// 替换前
require(member != address(0), "MembershipFacet: Invalid address");

// 替换后
if (member == address(0)) revert InvalidAddress();
```

---

## 📊 预期总收益

| 优化项 | Gas节省 | 频率 | 总影响 |
|--------|---------|------|--------|
| Selector缓存 | 2,000 | 每次创建DAO | 高 |
| Member packing | 15,000 | 每个成员 | 非常高 |
| Proposal packing | 60,000 | 每个提案 | 极高 |
| VotingPower缓存 | 5,000 | 每次投票处理 | 高 |
| Custom errors | 50 | 每次revert | 中 |

**总计额外节省**: 15-25% (在现有40-50%基础上)

---

## ⚠️ 注意事项

### Storage Layout变更
优化Member和Proposal会改变storage layout:
1. 现有DAO需要升级/迁移
2. 测试所有边界条件
3. 确保uint64/uint96/uint184足够大

---

## 🧪 验证脚本

创建benchmark测试:

```solidity
// test/foundry/GasOptimization.t.sol
contract GasOptimizationTest is Test {
    DAOFactory factoryOld;
    DAOFactory factoryNew;
    
    function testCompare_CreateDAO() public {
        // Before optimization
        uint256 gasBefore = gasleft();
        factoryOld.createDAO(config);
        uint256 gasOld = gasBefore - gasleft();
        
        // After optimization
        gasBefore = gasleft();
        factoryNew.createDAO(config);
        uint256 gasNew = gasBefore - gasleft();
        
        console.log("Old:", gasOld);
        console.log("New:", gasNew);
        console.log("Saved:", gasOld - gasNew);
        console.log("Percentage:", ((gasOld - gasNew) * 100) / gasOld);
    }
}
```

---

## 📚 参考资料

- [Solidity Gas Optimization Tips](https://github.com/iskdrews/awesome-solidity-gas-optimization)
- [Storage Layout](https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html)
- [Custom Errors](https://blog.soliditylang.org/2021/04/21/custom-errors/)

---
