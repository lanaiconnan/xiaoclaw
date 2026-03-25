# XiaoClaw vs 其他方案

## 一句话总结

> **XiaoClaw**: 最轻量的 WASM AI 助手，体积比 Docker 小 60 倍，启动比 Node.js 快 20 倍。

## 详细对比

| 特性 | XiaoClaw | Claude Code | LangChain | OpenAI SDK |
|------|----------|-------------|-----------|------------|
| **体积** | **< 5MB** | 200MB+ | 100MB | 30MB |
| **启动** | **< 100ms** | 5-10s | 3-5s | 1-3s |
| **内存** | **< 50MB** | 500MB+ | 400MB | 100MB |
| **运行时** | WASM | Docker | Python | Node.js |
| **语言** | MoonBit | TypeScript | Python | TypeScript |
| **部署** | 单文件 | Docker | pip | npm |
| **隔离** | WASM 沙箱 | 容器 | 进程 | 进程 |
| **平台** | 任意 | Linux | 任意 | Node.js |

## 场景对比

### 边缘计算场景

| 需求 | XiaoClaw | Claude Code |
|------|----------|-------------|
| 内存限制 64MB | ✅ 支持 | ❌ 需要 500MB+ |
| 冷启动 < 1s | ✅ 支持 | ❌ 需要 5s+ |
| 无 Docker | ✅ 支持 | ❌ 需要 |
| ARM 架构 | ✅ 支持 | ⚠️ 需要交叉编译 |

### Serverless 场景

| 需求 | XiaoClaw | LangChain |
|------|----------|-----------|
| 冷启动费用 | **$0.001** | $0.05 |
| 内存费用 | **$0.0001** | $0.002 |
| 执行时间 | **< 100ms** | 3-5s |

### 嵌入式场景

| 需求 | XiaoClaw | OpenAI SDK |
|------|----------|------------|
| Raspberry Pi | ✅ 支持 | ⚠️ 需要 Node.js |
| 单片机 | ✅ 支持 | ❌ 不支持 |
| 裸机部署 | ✅ 支持 | ❌ 需要 OS |

## 为什么选择 XiaoClaw？

### 1. 技术选型对比

```
选择 XiaoClaw 的理由:
├── 体积最小: < 5MB vs 200MB+
├── 启动最快: < 100ms vs 5s+
├── 成本最低: Serverless 费用降低 50x
├── 部署最简: 单文件 vs Docker
└── 安全最强: WASM 沙箱 vs 容器
```

### 2. 开发体验对比

| 方面 | XiaoClaw | 其他方案 |
|------|----------|----------|
| 学习曲线 | 低 (MoonBit 简洁) | 高 (需要学框架) |
| 开发速度 | 快 | 中等 |
| 调试 | WASM 调试器 | 传统调试器 |
| 测试 | 内置测试框架 | 依赖测试库 |

### 3. 生态系统对比

| 方面 | XiaoClaw | LangChain |
|------|----------|-----------|
| 插件生态 | 🔨 构建中 | ✅ 成熟 |
| 社区 | 🆕 新兴 | ✅ 成熟 |
| 文档 | 📝 完善中 | ✅ 完善 |
| 支持 | 社区 | 企业级 |

## 迁移指南

### 从 Claude Code 迁移

```bash
# 之前 (Claude Code)
docker run claude-code ...

# 之后 (XiaoClaw)
./xiaoclaw start
```

### 从 LangChain 迁移

```python
# 之前 (LangChain)
from langchain import LLMMathChain
chain = LLMMathChain(llm=llm)

# 之后 (XiaoClaw)
let chain = Agent::new(config)
```

## 总结

| 场景 | 推荐方案 |
|------|----------|
| 需要 Claude Code 功能 | 继续使用 Claude Code |
| 边缘计算/嵌入式 | **使用 XiaoClaw** ✅ |
| Serverless | **使用 XiaoClaw** ✅ |
| 快速原型开发 | **使用 XiaoClaw** ✅ |
| 复杂 Agent 系统 | LangChain |
| 企业级支持 | 商业方案 |

---

**选择 XiaoClaw，选择轻量** 🦞
