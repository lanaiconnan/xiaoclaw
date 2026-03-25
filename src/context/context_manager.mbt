// XiaoClaw Context Manager
// 防止 Context Rot（上下文腐烂）
// 灵感来自 GSD 的 Context Engineering 设计

// ============================================================
// 核心思想（来自 GSD）：
//   "Context rot — the quality degradation that happens as
//    Claude fills its context window."
//
// 解决方案：
//   1. 追踪上下文使用量
//   2. 超过阈值时自动压缩
//   3. 关键状态持久化到文件（STATE.md 风格）
//   4. 子任务在独立上下文中运行
// ============================================================

// 上下文条目类型
enum ContextEntryType {
  UserMessage       // 用户消息
  AssistantMessage  // 助手回复
  SystemEvent       // 系统事件
  TaskResult        // 任务结果
  StateSnapshot     // 状态快照
}

// 上下文条目
struct ContextEntry {
  id: String
  entry_type: ContextEntryType
  content: String
  token_estimate: Int
  timestamp: Int
  importance: Int   // 1-10，重要性评分
  pinned: Bool      // 是否固定（不被压缩）
}

// 上下文压缩策略
enum CompressionStrategy {
  DropOldest        // 丢弃最旧的条目
  SummarizeOldest   // 摘要最旧的条目
  DropLowImportance // 丢弃低重要性条目
  Hybrid            // 混合策略（推荐）
}

// 上下文状态
struct ContextState {
  session_id: String
  entries: Array[ContextEntry]
  total_tokens: Int
  max_tokens: Int
  compression_threshold: Double  // 触发压缩的阈值（0.0-1.0）
  strategy: CompressionStrategy
  compression_count: Int
  created_at: Int
  last_compressed_at: Int?
}

// 上下文管理器
struct ContextManager {
  state: ContextState
  state_file: String   // STATE.md 路径
  summary_file: String // SUMMARY.md 路径
  on_compress: (String) -> Unit  // 压缩回调
}

fn ContextManager::new(session_id: String, max_tokens: Int) -> ContextManager {
  let state = ContextState::{
    session_id: session_id,
    entries: [],
    total_tokens: 0,
    max_tokens: max_tokens,
    compression_threshold: 0.75,  // 75% 时触发压缩
    strategy: Hybrid,
    compression_count: 0,
    created_at: now(),
    last_compressed_at: None,
  }

  ContextManager::{
    state: state,
    state_file: ".planning/STATE.md",
    summary_file: ".planning/SUMMARY.md",
    on_compress: |summary| log_info("Context compressed: \(summary)"),
  }
}

// 添加条目
fn ContextManager::add(
  self: ContextManager,
  entry_type: ContextEntryType,
  content: String,
  importance: Int
) -> Unit {
  let tokens = estimate_tokens(content)

  let entry = ContextEntry::{
    id: generate_id(),
    entry_type: entry_type,
    content: content,
    token_estimate: tokens,
    timestamp: now(),
    importance: importance,
    pinned: false,
  }

  self.state.entries.push(entry)
  self.state.total_tokens = self.state.total_tokens + tokens

  // 检查是否需要压缩
  let usage_ratio = self.state.total_tokens.to_double() / self.state.max_tokens.to_double()
  if usage_ratio >= self.state.compression_threshold {
    self.compress()
  }
}

// 添加用户消息
fn ContextManager::add_user_message(self: ContextManager, content: String) -> Unit {
  self.add(UserMessage, content, 7)
}

// 添加助手回复
fn ContextManager::add_assistant_message(self: ContextManager, content: String) -> Unit {
  self.add(AssistantMessage, content, 6)
}

// 添加任务结果（高重要性）
fn ContextManager::add_task_result(self: ContextManager, content: String) -> Unit {
  self.add(TaskResult, content, 9)
}

// 固定条目（不被压缩）
fn ContextManager::pin_entry(self: ContextManager, id: String) -> Unit {
  for entry in self.state.entries {
    if entry.id == id {
      entry.pinned = true
      return
    }
  }
}

// 压缩上下文
fn ContextManager::compress(self: ContextManager) -> Unit {
  log_info("Context compression triggered (usage: \(self.usage_percent())%)")

  match self.state.strategy {
    DropOldest => self.compress_drop_oldest(),
    SummarizeOldest => self.compress_summarize_oldest(),
    DropLowImportance => self.compress_drop_low_importance(),
    Hybrid => self.compress_hybrid(),
  }

  self.state.compression_count = self.state.compression_count + 1
  self.state.last_compressed_at = Some(now())

  // 保存状态到文件
  self.save_state()

  log_info("Context compressed. New usage: \(self.usage_percent())%")
}

// 混合压缩策略（推荐）
// 1. 保留所有 pinned 条目
// 2. 保留最近 N 条高重要性条目
// 3. 摘要其余条目
fn ContextManager::compress_hybrid(self: ContextManager) -> Unit {
  let target_tokens = (self.state.max_tokens.to_double() * 0.5).to_int()

  // 分类条目
  let mut pinned = []
  let mut high_importance = []  // importance >= 8
  let mut normal = []

  for entry in self.state.entries {
    if entry.pinned {
      pinned.push(entry)
    } else if entry.importance >= 8 {
      high_importance.push(entry)
    } else {
      normal.push(entry)
    }
  }

  // 按时间排序（最新的在前）
  high_importance.sort(|a, b| b.timestamp - a.timestamp)
  normal.sort(|a, b| b.timestamp - a.timestamp)

  // 构建保留列表
  let mut kept = []
  let mut kept_tokens = 0

  // 1. 先保留所有 pinned
  for entry in pinned {
    kept.push(entry)
    kept_tokens = kept_tokens + entry.token_estimate
  }

  // 2. 保留最近的高重要性条目
  for entry in high_importance {
    if kept_tokens + entry.token_estimate <= target_tokens {
      kept.push(entry)
      kept_tokens = kept_tokens + entry.token_estimate
    }
  }

  // 3. 保留最近的普通条目（如果还有空间）
  for entry in normal {
    if kept_tokens + entry.token_estimate <= target_tokens {
      kept.push(entry)
      kept_tokens = kept_tokens + entry.token_estimate
    }
  }

  // 生成被丢弃条目的摘要
  let dropped_count = self.state.entries.length() - kept.length()
  if dropped_count > 0 {
    let summary = self.generate_summary(dropped_count)
    let summary_entry = ContextEntry::{
      id: generate_id(),
      entry_type: StateSnapshot,
      content: summary,
      token_estimate: estimate_tokens(summary),
      timestamp: now(),
      importance: 10,
      pinned: true,  // 摘要永远固定
    }
    kept.push(summary_entry)
    kept_tokens = kept_tokens + summary_entry.token_estimate
  }

  // 更新状态
  self.state.entries = kept
  self.state.total_tokens = kept_tokens

  self.on_compress("Dropped \(dropped_count) entries, kept \(kept.length())")
}

// 丢弃最旧的条目
fn ContextManager::compress_drop_oldest(self: ContextManager) -> Unit {
  let target = (self.state.max_tokens.to_double() * 0.5).to_int()

  // 按时间排序，保留最新的
  self.state.entries.sort(|a, b| b.timestamp - a.timestamp)

  let mut kept = []
  let mut tokens = 0

  for entry in self.state.entries {
    if entry.pinned || tokens + entry.token_estimate <= target {
      kept.push(entry)
      tokens = tokens + entry.token_estimate
    }
  }

  self.state.entries = kept
  self.state.total_tokens = tokens
}

// 丢弃低重要性条目
fn ContextManager::compress_drop_low_importance(self: ContextManager) -> Unit {
  let target = (self.state.max_tokens.to_double() * 0.5).to_int()

  // 按重要性排序
  self.state.entries.sort(|a, b| b.importance - a.importance)

  let mut kept = []
  let mut tokens = 0

  for entry in self.state.entries {
    if entry.pinned || tokens + entry.token_estimate <= target {
      kept.push(entry)
      tokens = tokens + entry.token_estimate
    }
  }

  self.state.entries = kept
  self.state.total_tokens = tokens
}

// 摘要最旧的条目
fn ContextManager::compress_summarize_oldest(self: ContextManager) -> Unit {
  // 简化实现：生成摘要后替换旧条目
  self.compress_hybrid()
}

// 生成摘要
fn ContextManager::generate_summary(self: ContextManager, dropped_count: Int) -> String {
  let mut summary_lines = [
    "## Context Summary (Auto-generated)",
    "",
    "Previous context compressed. Key points:",
    "",
  ]

  // 提取高重要性条目的关键信息
  let mut key_points = []
  for entry in self.state.entries {
    if entry.importance >= 8 && !entry.pinned {
      let preview = if entry.content.length() > 100 {
        entry.content.substring(0, 100) + "..."
      } else {
        entry.content
      }
      key_points.push("- [\(entry_type_to_string(entry.entry_type))] \(preview)")
    }
  }

  for point in key_points {
    summary_lines.push(point)
  }

  summary_lines.push("")
  summary_lines.push("*\(dropped_count) entries compressed at \(format_time(now()))*")

  String::join(summary_lines, "\n")
}

// 保存状态到文件（STATE.md 风格）
fn ContextManager::save_state(self: ContextManager) -> Unit {
  let content = self.render_state_md()
  write_file(self.state_file, content)
  log_info("State saved to \(self.state_file)")
}

// 渲染 STATE.md
fn ContextManager::render_state_md(self: ContextManager) -> String {
  let lines = [
    "# XiaoClaw Session State",
    "",
    "<!-- Auto-generated by ContextManager — do not edit manually -->",
    "",
    "## Session Info",
    "",
    "| Key | Value |",
    "|-----|-------|",
    "| Session ID | `\(self.state.session_id)` |",
    "| Created | \(format_time(self.state.created_at)) |",
    "| Context Usage | \(self.usage_percent())% (\(self.state.total_tokens)/\(self.state.max_tokens) tokens) |",
    "| Compressions | \(self.state.compression_count) |",
    "",
    "## Context Health",
    "",
    self.render_health_bar(),
    "",
    "## Pinned Context",
    "",
  ]

  let mut pinned_lines = []
  for entry in self.state.entries {
    if entry.pinned {
      pinned_lines.push("### \(entry_type_to_string(entry.entry_type)) @ \(format_time(entry.timestamp))")
      pinned_lines.push("")
      pinned_lines.push(entry.content)
      pinned_lines.push("")
    }
  }

  let all_lines = lines + pinned_lines + [
    "## Recent Entries",
    "",
    "| Time | Type | Importance | Preview |",
    "|------|------|------------|---------|",
  ]

  let mut entry_lines = []
  let recent = self.state.entries.slice(
    max(0, self.state.entries.length() - 10),
    self.state.entries.length()
  )
  for entry in recent {
    let preview = if entry.content.length() > 50 {
      entry.content.substring(0, 50) + "..."
    } else {
      entry.content
    }
    entry_lines.push("| \(format_time(entry.timestamp)) | \(entry_type_to_string(entry.entry_type)) | \(entry.importance)/10 | \(preview) |")
  }

  String::join(all_lines + entry_lines, "\n")
}

// 渲染健康条
fn ContextManager::render_health_bar(self: ContextManager) -> String {
  let pct = self.usage_percent()
  let filled = (pct / 5).to_int()
  let empty = 20 - filled

  let bar = "█".repeat(filled) + "░".repeat(empty)
  let status = if pct < 50 {
    "🟢 Healthy"
  } else if pct < 75 {
    "🟡 Warning"
  } else {
    "🔴 Critical"
  }

  "`[\(bar)] \(pct)%` \(status)"
}

// 获取使用百分比
fn ContextManager::usage_percent(self: ContextManager) -> Int {
  (self.state.total_tokens.to_double() / self.state.max_tokens.to_double() * 100.0).to_int()
}

// 获取上下文快照（用于子任务）
fn ContextManager::get_snapshot(self: ContextManager) -> String {
  let mut lines = [
    "## Context Snapshot",
    "",
    "Session: \(self.state.session_id)",
    "Usage: \(self.usage_percent())%",
    "",
    "### Key Context",
    "",
  ]

  // 只包含高重要性和 pinned 条目
  for entry in self.state.entries {
    if entry.pinned || entry.importance >= 8 {
      lines.push("**[\(entry_type_to_string(entry.entry_type))]** \(entry.content)")
      lines.push("")
    }
  }

  String::join(lines, "\n")
}

// 创建子上下文（用于独立子任务）
fn ContextManager::create_child_context(self: ContextManager, task_name: String) -> ContextManager {
  let child_session_id = "\(self.state.session_id)-\(task_name)"

  let mut child = ContextManager::new(child_session_id, self.state.max_tokens)

  // 注入父上下文快照
  let snapshot = self.get_snapshot()
  child.add(StateSnapshot, snapshot, 10)
  child.pin_entry(child.state.entries[0].id)

  log_info("Child context created for task: \(task_name)")
  child
}

// 统计信息
fn ContextManager::get_stats(self: ContextManager) -> ContextStats {
  let mut type_counts = Map::new()
  let mut total_importance = 0

  for entry in self.state.entries {
    let type_name = entry_type_to_string(entry.entry_type)
    let count = type_counts.get(type_name).unwrap_or(0)
    type_counts.set(type_name, count + 1)
    total_importance = total_importance + entry.importance
  }

  let avg_importance = if self.state.entries.length() > 0 {
    total_importance / self.state.entries.length()
  } else {
    0
  }

  ContextStats::{
    total_entries: self.state.entries.length(),
    total_tokens: self.state.total_tokens,
    max_tokens: self.state.max_tokens,
    usage_percent: self.usage_percent(),
    compression_count: self.state.compression_count,
    avg_importance: avg_importance,
    pinned_count: self.state.entries.filter(|e| e.pinned).length(),
  }
}

// 上下文统计
struct ContextStats {
  total_entries: Int
  total_tokens: Int
  max_tokens: Int
  usage_percent: Int
  compression_count: Int
  avg_importance: Int
  pinned_count: Int
}

// 辅助函数
fn estimate_tokens(text: String) -> Int {
  // 粗略估算：平均每 4 个字符 = 1 token
  (text.length().to_double() / 4.0).to_int() + 1
}

fn entry_type_to_string(t: ContextEntryType) -> String {
  match t {
    UserMessage => "User"
    AssistantMessage => "Assistant"
    SystemEvent => "System"
    TaskResult => "TaskResult"
    StateSnapshot => "Snapshot"
  }
}

fn format_time(ts: Int) -> String {
  // 简化实现
  "T\(ts)"
}

fn generate_id() -> String {
  "ctx-\(now())-\(random_int(1000, 9999))"
}
