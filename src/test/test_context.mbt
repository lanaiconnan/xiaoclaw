// XiaoClaw - Context Manager 测试
// 覆盖：添加条目、压缩、顺序、pin、子上下文、统计

fn test_context_initial_state() -> TestResult {
  let ctx = ContextManager::new("test-session", 1000)
  let stats = ctx.get_stats()
  let passed = stats.total_entries == 0 &&
    stats.total_tokens == 0 &&
    stats.usage_percent == 0 &&
    stats.compression_count == 0

  { name: "ContextManager::初始状态为空", passed, message: if passed { "ok" } else { "初始状态不正确" }, duration: 0 }
}

fn test_context_add_user_message() -> TestResult {
  let ctx = ContextManager::new("test-session", 10000)
  ctx.add_user_message("你好")
  let stats = ctx.get_stats()
  let passed = stats.total_entries == 1 && stats.total_tokens > 0

  { name: "ContextManager::添加用户消息", passed, message: if passed { "ok" } else { "entries=\(stats.total_entries) tokens=\(stats.total_tokens)" }, duration: 0 }
}

fn test_context_add_multiple_types() -> TestResult {
  let ctx = ContextManager::new("test-session", 10000)
  ctx.add_user_message("用户消息")
  ctx.add_assistant_message("助手回复")
  ctx.add_task_result("任务结果")
  let stats = ctx.get_stats()
  let passed = stats.total_entries == 3

  { name: "ContextManager::添加多种类型条目", passed, message: if passed { "ok" } else { "entries=\(stats.total_entries)" }, duration: 0 }
}

fn test_context_usage_percent() -> TestResult {
  // max_tokens=100，添加约 50 tokens 的内容
  let ctx = ContextManager::new("test-session", 100)
  // 每条约 5 tokens（20字符/4）
  ctx.add("AAAAAAAAAAAAAAAAAAA", UserMessage, 5)  // ~5 tokens
  let stats = ctx.get_stats()
  let passed = stats.usage_percent > 0 && stats.usage_percent <= 100

  { name: "ContextManager::使用率计算", passed, message: if passed { "ok" } else { "usage_percent=\(stats.usage_percent)" }, duration: 0 }
}

fn test_context_pin_entry() -> TestResult {
  let ctx = ContextManager::new("test-session", 10000)
  ctx.add_user_message("重要消息")

  let stats_before = ctx.get_stats()
  let passed_before = stats_before.pinned_count == 0

  // 获取第一条 entry 的 id 并 pin
  if ctx.state.entries.length() > 0 {
    let id = ctx.state.entries[0].id
    ctx.pin_entry(id)
  }

  let stats_after = ctx.get_stats()
  let passed = passed_before && stats_after.pinned_count == 1

  { name: "ContextManager::pin 条目", passed, message: if passed { "ok" } else { "pinned_count=\(stats_after.pinned_count)" }, duration: 0 }
}

fn test_context_compression_triggered() -> TestResult {
  // max_tokens=200，threshold=0.75，触发阈值=150 tokens
  let ctx = ContextManager::new("test-session", 200)
  // 每条约 25 tokens（100字符/4）
  let long_text = "A".repeat(100)
  let mut i = 0
  while i < 8 {
    ctx.add_user_message(long_text)
    i = i + 1
  }
  let stats = ctx.get_stats()
  // 压缩后使用率应该低于 75%
  let passed = stats.compression_count > 0 && stats.usage_percent < 75

  { name: "ContextManager::压缩触发", passed, message: if passed { "ok" } else { "compression_count=\(stats.compression_count) usage=\(stats.usage_percent)%" }, duration: 0 }
}

fn test_context_compression_preserves_order() -> TestResult {
  // 🔴 Fix #7 验证：压缩后消息顺序必须正确
  let ctx = ContextManager::new("test-session", 200)
  let long_text = "B".repeat(100)

  ctx.add_user_message("第一条消息")
  let mut i = 0
  while i < 6 {
    ctx.add_user_message(long_text)
    i = i + 1
  }
  ctx.add_user_message("最后一条消息")

  // 找到所有用户消息，检查时间戳顺序
  let user_msgs = ctx.state.entries.iter()
    .filter(fn(e) { e.entry_type == UserMessage })
    .collect()

  let mut order_correct = true
  let mut prev_ts = 0
  for entry in user_msgs {
    if entry.timestamp < prev_ts {
      order_correct = false
      break
    }
    prev_ts = entry.timestamp
  }

  { name: "ContextManager::压缩后顺序正确（Fix #7）", passed: order_correct, message: if order_correct { "ok" } else { "压缩后时间戳顺序乱了" }, duration: 0 }
}

fn test_context_pinned_entries_survive_compression() -> TestResult {
  let ctx = ContextManager::new("test-session", 200)

  // 添加一条重要消息并 pin
  ctx.add_user_message("必须保留的消息")
  if ctx.state.entries.length() > 0 {
    ctx.pin_entry(ctx.state.entries[0].id)
  }

  // 填满触发压缩
  let long_text = "C".repeat(100)
  let mut i = 0
  while i < 8 {
    ctx.add_user_message(long_text)
    i = i + 1
  }

  // pinned 条目应该还在
  let pinned_count = ctx.state.entries.iter().filter(fn(e) { e.pinned }).collect().length()
  let passed = pinned_count >= 1

  { name: "ContextManager::pinned 条目在压缩后保留", passed, message: if passed { "ok" } else { "pinned_count=\(pinned_count)" }, duration: 0 }
}

fn test_context_child_context_no_panic() -> TestResult {
  // 🔴 Fix #8 验证：create_child_context 不会 panic
  let ctx = ContextManager::new("parent", 10000)
  ctx.add_user_message("父上下文消息")

  // 不应该 panic
  let child = ctx.create_child_context("subtask")
  let passed = child.state.session_id == "parent-subtask"

  { name: "ContextManager::create_child_context 不 panic（Fix #8）", passed, message: if passed { "ok" } else { "session_id 不正确" }, duration: 0 }
}

fn test_context_empty_child_context() -> TestResult {
  // 空 context 创建子 context 也不应该 panic
  let ctx = ContextManager::new("empty-parent", 10000)
  let child = ctx.create_child_context("subtask")
  let passed = child.state.session_id == "empty-parent-subtask"

  { name: "ContextManager::空 context 创建子 context 不 panic", passed, message: if passed { "ok" } else { "panic 了" }, duration: 0 }
}

fn test_context_health_bar_format() -> TestResult {
  let ctx = ContextManager::new("test-session", 10000)
  let bar = ctx.render_health_bar()
  // 应该包含 % 和状态 emoji
  let passed = bar.contains("%") && (bar.contains("🟢") || bar.contains("🟡") || bar.contains("🔴"))

  { name: "ContextManager::healthBar 格式正确", passed, message: if passed { "ok" } else { "格式不对: \(bar)" }, duration: 0 }
}

fn test_context_get_snapshot() -> TestResult {
  let ctx = ContextManager::new("test-session", 10000)
  ctx.add_task_result("重要任务结果")  // importance=9，会出现在 snapshot

  let snapshot = ctx.get_snapshot()
  let passed = snapshot.length() > 0

  { name: "ContextManager::get_snapshot 非空", passed, message: if passed { "ok" } else { "snapshot 为空" }, duration: 0 }
}

// ============ 测试套件注册 ============

fn context_test_suite() -> TestSuite {
  TestSuite::{
    name: "Context Manager",
    tests: [
      test_context_initial_state,
      test_context_add_user_message,
      test_context_add_multiple_types,
      test_context_usage_percent,
      test_context_pin_entry,
      test_context_compression_triggered,
      test_context_compression_preserves_order,
      test_context_pinned_entries_survive_compression,
      test_context_child_context_no_panic,
      test_context_empty_child_context,
      test_context_health_bar_format,
      test_context_get_snapshot,
    ],
    setup: None,
    teardown: None,
  }
}
