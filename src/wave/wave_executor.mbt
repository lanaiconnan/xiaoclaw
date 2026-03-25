// XiaoClaw Wave Execution System
// 依赖感知的并行执行引擎
// 灵感来自 GSD 的 Wave Execution 设计
//
// ============================================================
// 核心思想（来自 GSD）：
//
//   WAVE 1 (parallel)     WAVE 2 (parallel)     WAVE 3
//   ┌─────────┐ ┌──────┐  ┌─────────┐ ┌──────┐  ┌──────┐
//   │ Plan 01 │ │ P02  │→ │ Plan 03 │ │ P04  │→ │ P05  │
//   │ User    │ │ Prod │  │ Orders  │ │ Cart │  │Check │
//   └─────────┘ └──────┘  └─────────┘ └──────┘  └──────┘
//
//   独立任务 → 同一 Wave → 并行执行
//   有依赖   → 下一 Wave → 等待前置完成
// ============================================================

// ============ DAG 节点（有向无环图）============

struct WaveNode {
  spec: TaskSpec
  dependencies: Array[String]   // 依赖的 spec id
  dependents: Array[String]     // 被哪些 spec 依赖
  wave_index: Int               // 所属 Wave 编号（-1 = 未分配）
  status: WaveNodeStatus
  result: SpecResult?
  started_at: Int?
  completed_at: Int?
}

enum WaveNodeStatus {
  Waiting     // 等待依赖完成
  Ready       // 可以执行
  Running     // 执行中
  Done        // 完成
  Failed      // 失败
  Skipped     // 跳过（依赖失败）
}

// ============ Wave（执行批次）============

struct Wave {
  index: Int
  nodes: Array[WaveNode]
  status: WaveStatus
  started_at: Int?
  completed_at: Int?
  parallel: Bool   // 是否并行执行
}

enum WaveStatus {
  Pending    // 等待前置 Wave 完成
  Running    // 执行中
  Done       // 全部完成
  PartialFail // 部分失败
  Failed     // 全部失败
}

// ============ Wave 执行计划 ============

struct WavePlan {
  id: String
  name: String
  waves: Array[Wave]
  total_nodes: Int
  created_at: Int
}

// ============ Wave 执行引擎 ============

struct WaveExecutor {
  context_manager: ContextManager
  spec_executor: SpecExecutor
  max_parallel: Int       // 每个 Wave 最大并行数
  fail_fast: Bool         // 遇到失败是否立即停止
  on_wave_start: (Int) -> Unit
  on_wave_done: (Int, WaveStatus) -> Unit
  on_node_done: (String, WaveNodeStatus) -> Unit
}

fn WaveExecutor::new(
  context_manager: ContextManager,
  spec_executor: SpecExecutor
) -> WaveExecutor {
  WaveExecutor::{
    context_manager: context_manager,
    spec_executor: spec_executor,
    max_parallel: 4,
    fail_fast: false,
    on_wave_start: |i| log_info("Wave \(i) started"),
    on_wave_done: |i, s| log_info("Wave \(i) done: \(wave_status_to_string(s))"),
    on_node_done: |id, s| log_info("Node \(id) done: \(node_status_to_string(s))"),
  }
}

// ============ DAG 构建器 ============

struct WavePlanBuilder {
  name: String
  nodes: Map[String, WaveNode]
}

fn WavePlanBuilder::new(name: String) -> WavePlanBuilder {
  WavePlanBuilder::{
    name: name,
    nodes: Map::new(),
  }
}

// 添加 Spec（无依赖）
fn WavePlanBuilder::add(self: WavePlanBuilder, spec: TaskSpec) -> WavePlanBuilder {
  let node = WaveNode::{
    spec: spec,
    dependencies: [],
    dependents: [],
    wave_index: -1,
    status: Ready,
    result: None,
    started_at: None,
    completed_at: None,
  }
  self.nodes.set(spec.id, node)
  self
}

// 添加 Spec（有依赖）
fn WavePlanBuilder::add_after(
  self: WavePlanBuilder,
  spec: TaskSpec,
  depends_on: Array[String]
) -> WavePlanBuilder {
  let node = WaveNode::{
    spec: spec,
    dependencies: depends_on,
    dependents: [],
    wave_index: -1,
    status: Waiting,
    result: None,
    started_at: None,
    completed_at: None,
  }
  self.nodes.set(spec.id, node)

  // 更新被依赖节点的 dependents 列表
  for dep_id in depends_on {
    match self.nodes.get(dep_id) {
      Some(dep_node) => {
        dep_node.dependents.push(spec.id)
      }
      None => {
        log_warn("Dependency not found: \(dep_id)")
      }
    }
  }

  self
}

// 构建 Wave 计划（拓扑排序）
fn WavePlanBuilder::build(self : WavePlanBuilder) -> Result[WavePlan, String] {
  match self.topological_sort() {
    Ok(waves) => Ok({
      id: "plan-\(now())",
      name: self.name,
      waves,
      total_nodes: self.nodes.length(),
      created_at: now(),
    })
    Err(e) => Err(e)
  }
}

// 拓扑排序 → 分配 Wave（Kahn's Algorithm）
fn WavePlanBuilder::topological_sort(self : WavePlanBuilder) -> Result[Array[Wave], String] {
  let mut in_degree : Map[String, Int] = {}
  let mut wave_map  : Map[String, Int] = {}

  for id, node in self.nodes {
    in_degree[id] = node.dependencies.length()
  }

  let mut current_wave_nodes : Array[String] = []
  for id, degree in in_degree {
    if degree == 0 {
      current_wave_nodes.push(id)
      wave_map[id] = 0
    }
  }

  let mut waves     : Array[Wave] = []
  let mut wave_index = 0
  let mut processed  = 0

  loop {
    if current_wave_nodes.length() == 0 {
      break
    }

    let wave_nodes : Array[WaveNode] = current_wave_nodes.map(fn(id) {
      let node = self.nodes[id].unwrap()
      node.wave_index = wave_index
      node
    })

    waves.push({
      index: wave_index,
      nodes: wave_nodes,
      status: Pending,
      started_at: None,
      completed_at: None,
      parallel: wave_nodes.length() > 1,
    })

    processed = processed + current_wave_nodes.length()

    let mut next_wave_nodes : Array[String] = []
    for id in current_wave_nodes {
      let node = self.nodes[id].unwrap()
      for dep_id in node.dependents {
        let degree = in_degree[dep_id].or(0) - 1
        in_degree[dep_id] = degree
        if degree == 0 {
          next_wave_nodes.push(dep_id)
          wave_map[dep_id] = wave_index + 1
        }
      }
    }

    current_wave_nodes = next_wave_nodes
    wave_index = wave_index + 1
  }

  // 🔴 Fix #12: 循环依赖检测返回 Err，不再静默
  if processed < self.nodes.length() {
    let unprocessed = self.nodes.keys().filter(fn(id) { wave_map[id].is_empty() }).collect()
    return Err("Circular dependency detected! Unresolved nodes: \(unprocessed.join(", "))")
  }

  Ok(waves)
}

// ============ 执行 Wave 计划 ============

fn WaveExecutor::execute_plan(
  self: WaveExecutor,
  plan: WavePlan,
  handlers: Map[String, (TaskSpec) -> Result[String]]
) -> WavePlanResult {
  let start_time = now_ms()

  log_info("═══════════════════════════════════════")
  log_info("Wave Plan: \(plan.name)")
  log_info("Total: \(plan.total_nodes) tasks, \(plan.waves.length()) waves")
  log_info("═══════════════════════════════════════")

  let mut wave_results = []
  let mut all_done = true

  for wave in plan.waves {
    // 检查是否需要停止（fail_fast 模式）
    if self.fail_fast && !all_done {
      log_warn("Fail-fast: skipping remaining waves")
      break
    }

    let wave_result = self.execute_wave(wave, handlers)
    wave_results.push(wave_result)

    if wave_result.status == Failed || wave_result.status == PartialFail {
      all_done = false
    }
  }

  let duration = now_ms() - start_time
  let success_count = wave_results.filter(|r| r.status == Done).length()

  log_info("═══════════════════════════════════════")
  log_info("Plan complete: \(success_count)/\(plan.waves.length()) waves succeeded (\(duration)ms)")
  log_info("═══════════════════════════════════════")

  WavePlanResult::{
    plan_id: plan.id,
    plan_name: plan.name,
    wave_results: wave_results,
    total_duration_ms: duration,
    success: all_done,
  }
}

// 执行单个 Wave
fn WaveExecutor::execute_wave(
  self: WaveExecutor,
  wave: Wave,
  handlers: Map[String, (TaskSpec) -> Result[String]]
) -> WaveResult {
  let start_time = now_ms()

  self.on_wave_start(wave.index)

  log_info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
  log_info("Wave \(wave.index): \(wave.nodes.length()) tasks (\(if wave.parallel { "parallel" } else { "sequential" }))")

  wave.status = Running
  wave.started_at = Some(now())

  let mut node_results = []

  if wave.parallel && wave.nodes.length() > 1 {
    // 并行执行（模拟）
    node_results = self.execute_parallel(wave.nodes, handlers)
  } else {
    // 顺序执行
    node_results = self.execute_sequential(wave.nodes, handlers)
  }

  let duration = now_ms() - start_time
  wave.completed_at = Some(now())

  let failed_count = node_results.filter(|r| r.status == Failed || r.status == Skipped).length()
  let done_count = node_results.filter(|r| r.status == Done).length()

  wave.status = if failed_count == 0 {
    Done
  } else if done_count > 0 {
    PartialFail
  } else {
    Failed
  }

  self.on_wave_done(wave.index, wave.status)

  log_info("Wave \(wave.index) done: \(done_count)/\(wave.nodes.length()) succeeded (\(duration)ms)")

  WaveResult::{
    wave_index: wave.index,
    node_results: node_results,
    status: wave.status,
    duration_ms: duration,
  }
}

// 并行执行节点
fn WaveExecutor::execute_parallel(
  self: WaveExecutor,
  nodes: Array[WaveNode],
  handlers: Map[String, (TaskSpec) -> Result[String]]
) -> Array[WaveNodeResult] {
  // MoonBit 暂不支持真正的并发，模拟并行语义
  // 实际部署时可替换为真正的并发实现
  log_info("Executing \(nodes.length()) tasks in parallel (simulated)...")

  let mut results = []
  let batches = nodes.chunks(self.max_parallel)

  for batch in batches {
    // 每批并行执行
    for node in batch {
      let result = self.execute_node(node, handlers)
      results.push(result)
    }
  }

  results
}

// 顺序执行节点
fn WaveExecutor::execute_sequential(
  self: WaveExecutor,
  nodes: Array[WaveNode],
  handlers: Map[String, (TaskSpec) -> Result[String]]
) -> Array[WaveNodeResult] {
  let mut results = []

  for node in nodes {
    let result = self.execute_node(node, handlers)
    results.push(result)

    // fail_fast 模式下遇到失败立即停止
    if self.fail_fast && result.status == Failed {
      log_warn("Fail-fast: stopping sequential execution")
      break
    }
  }

  results
}

// 执行单个节点
fn WaveExecutor::execute_node(
  self: WaveExecutor,
  node: WaveNode,
  handlers: Map[String, (TaskSpec) -> Result[String]]
) -> WaveNodeResult {
  let spec = node.spec
  let start_time = now_ms()

  log_info("  → \(spec.name) [\(spec.id)]")

  node.status = Running
  node.started_at = Some(now())

  // 获取 handler
  let handler = match handlers.get(spec.id) {
    Some(h) => h,
    None => {
      // 没有 handler，使用默认
      |s| Ok("No handler registered for \(s.id)")
    }
  }

  // 执行 Spec
  let spec_result = self.spec_executor.execute(spec, handler)

  let duration = now_ms() - start_time
  node.completed_at = Some(now())

  let status = match spec_result.status {
    Done => Done,
    _ => Failed,
  }

  node.status = status
  node.result = Some(spec_result)

  self.on_node_done(spec.id, status)

  log_info("  ✓ \(spec.name): \(node_status_to_string(status)) (\(duration)ms)")

  WaveNodeResult::{
    spec_id: spec.id,
    spec_name: spec.name,
    status: status,
    spec_result: spec_result,
    duration_ms: duration,
  }
}

// ============ 结果结构 ============

struct WavePlanResult {
  plan_id: String
  plan_name: String
  wave_results: Array[WaveResult]
  total_duration_ms: Int
  success: Bool
}

struct WaveResult {
  wave_index: Int
  node_results: Array[WaveNodeResult]
  status: WaveStatus
  duration_ms: Int
}

struct WaveNodeResult {
  spec_id: String
  spec_name: String
  status: WaveNodeStatus
  spec_result: SpecResult
  duration_ms: Int
}

// ============ 可视化 ============

fn WavePlan::visualize(self: WavePlan) -> String {
  let mut lines = [
    "Wave Execution Plan: \(self.name)",
    "═══════════════════════════════════════",
    "",
  ]

  for wave in self.waves {
    let parallel_label = if wave.parallel { " (parallel)" } else { " (sequential)" }
    lines.push("WAVE \(wave.index)\(parallel_label)")

    for node in wave.nodes {
      let deps = if node.dependencies.length() > 0 {
        " ← [\(String::join(node.dependencies, ", "))]"
      } else {
        ""
      }
      lines.push("  ┌─ \(node.spec.name) [\(node.spec.id)]\(deps)")
    }

    if wave.index < self.waves.length() - 1 {
      lines.push("  ↓")
    }

    lines.push("")
  }

  lines.push("Total: \(self.total_nodes) tasks in \(self.waves.length()) waves")

  String::join(lines, "\n")
}

fn WavePlanResult::summary(self: WavePlanResult) -> String {
  let mut lines = [
    "Wave Plan Result: \(self.plan_name)",
    "═══════════════════════════════════════",
    "",
    "Status: \(if self.success { "✅ SUCCESS" } else { "❌ FAILED" })",
    "Duration: \(self.total_duration_ms)ms",
    "",
  ]

  for wave_result in self.wave_results {
    let icon = match wave_result.status {
      Done => "✅"
      PartialFail => "⚠️"
      Failed => "❌"
      _ => "⏳"
    }
    lines.push("\(icon) Wave \(wave_result.wave_index) (\(wave_result.duration_ms)ms)")

    for node in wave_result.node_results {
      let node_icon = match node.status {
        Done => "  ✓"
        Failed => "  ✗"
        Skipped => "  ⊘"
        _ => "  ?"
      }
      lines.push("\(node_icon) \(node.spec_name) (\(node.duration_ms)ms)")
    }

    lines.push("")
  }

  String::join(lines, "\n")
}

// ============ 辅助函数 ============

fn wave_status_to_string(s: WaveStatus) -> String {
  match s {
    Pending => "Pending"
    Running => "Running"
    Done => "Done"
    PartialFail => "PartialFail"
    Failed => "Failed"
  }
}

fn node_status_to_string(s: WaveNodeStatus) -> String {
  match s {
    Waiting => "Waiting"
    Ready => "Ready"
    Running => "Running"
    Done => "Done"
    Failed => "Failed"
    Skipped => "Skipped"
  }
}
