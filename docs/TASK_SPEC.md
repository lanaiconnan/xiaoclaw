# XiaoClaw Task Spec 系统

> 规格驱动开发（Spec-Driven Development）
> 灵感来自 GSD 的 discuss → plan → execute → verify → ship 流程

## 核心思想

每个任务都有明确的 Spec：

```xml
<task type="auto" priority="P1-High">
  <goal>要做什么</goal>
  <context>背景信息</context>
  <action>具体怎么做</action>
  <verify>
    <description>如何验证</description>
    <expected>期望结果</expected>
  </verify>
  <done>什么叫做完成</done>
</task>
```

## 使用示例

### 创建 Spec

```moonbit
let spec = TaskSpecBuilder::new("发送飞书消息")
  .goal("通过飞书发送消息给用户")
  .context("用户请求发送通知")
  .action("调用 FeishuChannel::send_text() 方法")
  .verify("消息发送成功", "API 返回 200")
  .verify_with_command("API 可达", "curl http://api/health", "ok")
  .done("飞书消息已成功发送")
  .files(["src/channels/feishu.mbt"])
  .priority(P1)
  .tag("feishu")
  .build()
```

### 执行 Spec

```moonbit
let executor = SpecExecutor::new(context_manager)

let result = executor.execute(spec, |s| {
  // 实际执行逻辑
  feishu_channel.send_text(target, message)
  Ok("Message sent")
})

println("Status: \(spec_status_to_string(result.status))")
println("Verify: \(result.verify_results.filter(|v| v.passed).length())/\(result.verify_results.length()) passed")
```

### 查看 SUMMARY.md

执行完成后自动生成：

```markdown
# Task Summary: 发送飞书消息

| Field | Value |
|-------|-------|
| Status | ✅ Done |
| Duration | 234ms |
| Verify | 2/2 passed |

## Result
Message sent successfully

## Verification
✅ 消息发送成功
✅ API 可达
```

## 工作流

```
用户描述需求
    ↓
TaskSpecBuilder 构建 Spec
    ↓
SpecExecutor 执行
    ↓
自动验证（VerifyStep）
    ↓
生成 SUMMARY.md
    ↓
更新 ContextManager
```

## 预定义模板

| 模板 | 函数 |
|------|------|
| 飞书消息 | `create_feishu_message_spec()` |
| 定时任务 | `create_schedule_spec()` |
| 健康检查 | `create_health_check_spec()` |

## 与 GSD 的对比

| 特性 | GSD | XiaoClaw |
|------|-----|---------|
| Spec 格式 | XML | XML + Markdown |
| 验证步骤 | 内置 | VerifyStep |
| 摘要生成 | SUMMARY.md | SUMMARY.md |
| 子上下文 | 子 Agent | ChildContext |
| 注册表 | 文件系统 | SpecRegistry |

---

**Task Spec 让每个任务都有明确的目标和验证** 🦞
