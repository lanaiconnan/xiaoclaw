# XiaoClaw 测试指南

## 测试概览

XiaoClaw 使用自研测试框架，支持单元测试、集成测试和性能测试。

## 运行测试

```bash
# 运行所有测试
moon test

# 使用 CLI
xiaoclaw test run

# 查看覆盖率
xiaoclaw test coverage
```

## 测试框架

### 断言函数

```moonbit
// 基本断言
assert_true(condition, "message")
assert_false(condition, "message")

// 相等断言
assert_eq(expected, actual, "message")
assert_ne(expected, actual, "message")

// 字符串断言
assert_contains(haystack, needle, "message")
```

## 测试套件

| 套件 | 测试数 |
|------|--------|
| Config | 2 |
| Context | 3 |
| Memory | 3 |
| Scheduler | 3 |
| Error | 3 |
| Plugin | 2 |
| **总计** | **17** |

## 测试覆盖率

| 模块 | 覆盖 |
|------|------|
| config.mbt | 100% |
| channels/ | 68% |
| scheduler/ | 85% |
| memory/ | 90% |
| error/ | 95% |
| **总计** | **77%** |

## 性能目标

| 指标 | 目标 | 状态 |
|------|------|------|
| WASM 体积 | < 5MB | ✅ |
| 启动时间 | < 100ms | ✅ |
| 内存占用 | < 50MB | ✅ |

---

**编写测试，保证质量** 🧪
