# XiaoClaw Context Manager

> 防止 Context Rot（上下文腐烂）
> 灵感来自 GSD 的 Context Engineering 设计

## 什么是 Context Rot？

随着对话越来越长，AI 的输出质量会逐渐下降。这是因为：

1. 上下文窗口被填满
2. 早期的重要信息被稀释
3. AI 开始"忘记"关键决策

GSD 的解决方案：**Context Engineering**

## XiaoClaw 的解决方案

### 核心机制

```
用户消息 → ContextManager → 自动压缩 → 保持质量
                ↓
           STATE.md（持久化）
```

### 压缩策略

| 策略 | 说明 | 适用场景 |
|------|------|---------|
| `Hybrid` | 混合策略（推荐） | 通用 |
| `DropOldest` | 丢弃最旧 | 时效性强 |
| `DropLowImportance` | 丢弃低重要性 | 重要性差异大 |
| `SummarizeOldest` | 摘要最旧 | 需要历史记录 |

### 重要性评分

| 分数 | 类型 | 说明 |
|------|------|------|
| 10 | 状态快照 | 永远保留 |
| 9 | 任务结果 | 高优先级 |
| 7 | 用户消息 | 正常优先级 |
| 6 | 助手回复 | 正常优先级 |

## 使用示例

```moonbit
// 创建 Context Manager
let ctx = ContextManager::new("session-001", 200000)

// 添加消息
ctx.add_user_message("帮我发送飞书消息")
ctx.add_assistant_message("好的，我来帮你发送")
ctx.add_task_result("飞书消息发送成功")

// 查看状态
let stats = ctx.get_stats()
println("Usage: \(stats.usage_percent)%")

// 创建子上下文（独立任务）
let child = ctx.create_child_context("send-feishu")
```

## STATE.md 格式

```markdown
# XiaoClaw Session State

## Session Info
| Key | Value |
|-----|-------|
| Session ID | `session-001` |
| Context Usage | 45% |

## Context Health
`[█████████░░░░░░░░░░░] 45%` 🟡 Warning

## Pinned Context
...
```

## 与 GSD 的对比

| 特性 | GSD | XiaoClaw |
|------|-----|---------|
| 上下文压缩 | 子 Agent 独立上下文 | ContextManager 自动压缩 |
| 状态持久化 | STATE.md | STATE.md |
| 压缩策略 | 新 Agent 窗口 | Hybrid 策略 |
| 重要性评分 | 隐式 | 显式 1-10 |

---

**Context Manager 让 XiaoClaw 保持长期高质量输出** 🦞
