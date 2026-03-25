# XiaoClaw Wave Execution System

> 依赖感知的并行执行引擎
> 灵感来自 GSD 的 Wave Execution 设计

## 核心思想

```
WAVE 0 (parallel)     WAVE 1 (parallel)     WAVE 2
┌─────────┐ ┌──────┐  ┌─────────┐ ┌──────┐  ┌──────┐
│ Setup   │ │ Init │→ │  Core   │ │Tests │→ │ Ship │
│         │ │      │  │         │ │      │  │      │
└─────────┘ └──────┘  └─────────┘ └──────┘  └──────┘
     独立 → 同一 Wave → 并行执行
     有依赖 → 下一 Wave → 等待前置完成
```

## 使用示例

### 构建 Wave 计划

```moonbit
let plan = WavePlanBuilder::new("用户认证系统")
  // Wave 0: 独立任务，并行执行
  .add(user_model_spec)
  .add(product_model_spec)
  // Wave 1: 依赖 Wave 0
  .add_after(orders_api_spec, [user_model_spec.id])
  .add_after(cart_api_spec, [product_model_spec.id])
  // Wave 2: 依赖 Wave 1
  .add_after(checkout_spec, [orders_api_spec.id, cart_api_spec.id])
  .build()
```

### 可视化计划

```
Wave Execution Plan: 用户认证系统
═══════════════════════════════════════

WAVE 0 (parallel)
  ┌─ User Model [spec-user-model]
  ┌─ Product Model [spec-product-model]
  ↓

WAVE 1 (parallel)
  ┌─ Orders API [spec-orders-api] ← [spec-user-model]
  ┌─ Cart API [spec-cart-api] ← [spec-product-model]
  ↓

WAVE 2 (sequential)
  ┌─ Checkout [spec-checkout] ← [spec-orders-api, spec-cart-api]

Total: 5 tasks in 3 waves
```

### 执行计划

```moonbit
let executor = WaveExecutor::new(context_manager, spec_executor)

let result = executor.execute_plan(plan, handlers)

println(result.summary())
```

## Quick/Full 模式

### Fast 模式（极速）

```bash
xiaoclaw run "改个配置" --fast
```

- ⚡ 完全跳过规划
- 直接执行
- 适合：小修小补

### Quick 模式（快速）

```bash
xiaoclaw run "添加飞书通知" --quick
xiaoclaw run "添加飞书通知" --quick --discuss
xiaoclaw run "添加飞书通知" --quick --verify
```

- 🚀 跳过 research
- 可选 discuss 和 verify
- 适合：中等复杂度

### Full 模式（完整）

```bash
xiaoclaw run "重构消息通道系统" --full
xiaoclaw run "重构消息通道系统" --full --dry-run
```

- 🔬 完整流程
- discuss → research → plan → wave execute → verify
- 适合：复杂功能

### Flags 可组合

```bash
# Quick + discuss + verify
xiaoclaw run "任务描述" --quick --discuss --verify

# Full + dry-run（只生成计划，不执行）
xiaoclaw run "任务描述" --full --dry-run
```

## 执行结果

```
Wave Plan Result: 用户认证系统
═══════════════════════════════════════

Status: ✅ SUCCESS
Duration: 1234ms

✅ Wave 0 (456ms)
  ✓ User Model (234ms)
  ✓ Product Model (222ms)

✅ Wave 1 (567ms)
  ✓ Orders API (289ms)
  ✓ Cart API (278ms)

✅ Wave 2 (211ms)
  ✓ Checkout (211ms)
```

## 与 GSD 的对比

| 特性 | GSD | XiaoClaw |
|------|-----|---------|
| Wave 执行 | 真正并发 | 模拟并行（MoonBit 限制） |
| 依赖图 | 隐式（文件依赖） | 显式 DAG |
| 拓扑排序 | 自动 | Kahn's Algorithm |
| Fail-fast | 支持 | 支持 |
| 可视化 | 无 | ASCII 图 |
| Quick 模式 | `/gsd:quick` | `--quick` flag |
| Full 模式 | `/gsd:new-project` | `--full` flag |

---

**Wave Execution 让复杂任务高效并行执行** 🦞
