# XiaoClaw Jobs System

> 基于 MoonClaw 设计模式的任务管理系统

## 概述

Jobs System 提供了一个强大的任务队列和执行框架，支持：

- ✅ 优先级队列
- ✅ 自动重试
- ✅ 多种任务类型
- ✅ 工作流支持
- ✅ 批处理
- ✅ 定时任务

## 核心概念

### Job 状态

```
Pending → Running → Completed
           ↓
         Failed → Retrying → Running
           ↓
        Cancelled
```

### Job 优先级

| 优先级 | 说明 |
|--------|------|
| Critical | 最高优先级 |
| High | 高优先级 |
| Normal | 普通优先级 |
| Low | 低优先级 |

## 使用示例

### 1. 创建简单 Job

```moonbit
let job = JobBuilder::new("task-1", "My Task")
  .with_description("A simple task")
  .with_priority(Normal)
  .with_retries(3)
  .build(|| {
    // 任务逻辑
    Ok("Task completed")
  })
```

### 2. 创建队列并执行

```moonbit
let queue = JobQueue::new(4)  // 最多 4 个并发任务

queue.enqueue(job)
queue.start()

// 查看统计
let stats = queue.get_stats()
println("Total: \(stats.total), Running: \(stats.running)")
```

### 3. 定时任务

```moonbit
let scheduled = ScheduledJob::new(
  "daily-report",
  "每日报告",
  "0 9 * * *",  // 每天早上 9 点
  || Ok("Report sent")
)
```

### 4. 延迟任务

```moonbit
let delayed = DelayedJob::new(
  "delayed-task",
  "延迟任务",
  5000,  // 5 秒后执行
  || Ok("Delayed task completed")
)
```

### 5. 周期性任务

```moonbit
let periodic = PeriodicJob::new(
  "health-check",
  "健康检查",
  60000,  // 每 60 秒执行一次
  || Ok("Health check passed")
)
.with_max_executions(100)  // 最多执行 100 次
```

### 6. 工作流任务

```moonbit
let workflow = WorkflowJob::new("workflow-1", "数据处理流程")
  .add_step("验证数据", || Ok("Validation passed"))
  .add_step("处理数据", || Ok("Processing completed"))
  .add_step("保存结果", || Ok("Saved"))

queue.enqueue(workflow.base)
```

### 7. 批处理任务

```moonbit
let items = [1, 2, 3, 4, 5]
let batch = BatchJob::new(
  "batch-1",
  "批处理",
  items,
  |item| Ok("Processed \(item)")
)
.with_batch_size(2)

queue.enqueue(batch.base)
```

## 预定义任务

### 每日摘要

```moonbit
let job = create_daily_summary_job(|| {
  Ok("Daily summary sent")
})
```

### 健康检查

```moonbit
let job = create_health_check_job()
```

### 数据清理

```moonbit
let job = create_cleanup_job(30)  // 清理 30 天前的数据
```

### 数据备份

```moonbit
let job = create_backup_job("s3://bucket")
```

## 错误处理

Jobs System 使用 `Result` 类型处理错误：

```moonbit
fn my_job() -> Result[String] {
  match some_operation() {
    Ok(result) => Ok(result),
    Err(e) => Err(NetworkError("Connection failed"))
  }
}
```

## 监控和统计

```moonbit
let stats = queue.get_stats()

println("总任务数: \(stats.total)")
println("待处理: \(stats.pending)")
println("运行中: \(stats.running)")
println("已完成: \(stats.completed)")
println("失败: \(stats.failed)")
```

## 最佳实践

1. **设置合理的重试次数**
   - 网络任务: 3-5 次
   - 本地任务: 1-2 次

2. **使用优先级**
   - 关键任务: Critical
   - 定时任务: Normal
   - 清理任务: Low

3. **添加标签**
   ```moonbit
   .with_tag("monitoring")
   .with_tag("daily")
   ```

4. **监控队列**
   - 定期检查统计信息
   - 设置告警阈值

5. **优雅关闭**
   ```moonbit
   queue.stop()
   ```

## 性能考虑

- **并发数**: 根据系统资源调整
- **批大小**: 平衡吞吐量和延迟
- **重试延迟**: 使用指数退避

## 与 Cron 的区别

| 特性 | Cron | Jobs |
|------|------|------|
| 定时执行 | ✅ | ✅ |
| 优先级 | ❌ | ✅ |
| 重试机制 | ❌ | ✅ |
| 工作流 | ❌ | ✅ |
| 批处理 | ❌ | ✅ |
| 队列管理 | ❌ | ✅ |

---

**Jobs System 让任务管理更强大** 🦞
