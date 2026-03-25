// XiaoClaw Quick/Full Mode
// 快速模式 + 完整模式
// 灵感来自 GSD 的 /gsd:quick 和 /gsd:new-project 设计
//
// ============================================================
// 核心思想（来自 GSD）：
//
//   /gsd:quick  → 跳过规划，直接执行（小任务）
//   /gsd:fast   → 极速模式，完全跳过规划
//   /gsd:new-project → 完整流程（大项目）
//
//   flags 可组合：
//     --discuss   先收集上下文
//     --research  先调研方案
//     --full      完整验证
// ============================================================

// 执行模式
enum ExecutionMode {
  Quick    // 快速：跳过规划，直接执行
  Full     // 完整：discuss → plan → execute → verify → ship
  Fast     // 极速：完全跳过规划和验证
  Auto     // 自动：根据任务复杂度选择
}

// 执行选项（flags 可组合）
struct ExecutionOptions {
  mode: ExecutionMode
  discuss: Bool     // 先收集上下文（--discuss）
  research: Bool    // 先调研方案（--research）
  verify: Bool      // 执行后验证（--verify）
  plan_check: Bool  // 执行前检查计划（--plan-check）
  dry_run: Bool     // 只生成计划，不执行（--dry-run）
  verbose: Bool     // 详细输出（--verbose）
}

fn ExecutionOptions::quick() -> ExecutionOptions {
  ExecutionOptions::{
    mode: Quick,
    discuss: false,
    research: false,
    verify: false,
    plan_check: false,
    dry_run: false,
    verbose: false,
  }
}

fn ExecutionOptions::full() -> ExecutionOptions {
  ExecutionOptions::{
    mode: Full,
    discuss: true,
    research: true,
    verify: true,
    plan_check: true,
    dry_run: false,
    verbose: true,
  }
}

fn ExecutionOptions::fast() -> ExecutionOptions {
  ExecutionOptions::{
    mode: Fast,
    discuss: false,
    research: false,
    verify: false,
    plan_check: false,
    dry_run: false,
    verbose: false,
  }
}

fn ExecutionOptions::with_discuss(self: ExecutionOptions) -> ExecutionOptions {
  ExecutionOptions::{ ..self, discuss: true }
}

fn ExecutionOptions::with_research(self: ExecutionOptions) -> ExecutionOptions {
  ExecutionOptions::{ ..self, research: true }
}

fn ExecutionOptions::with_verify(self: ExecutionOptions) -> ExecutionOptions {
  ExecutionOptions::{ ..self, verify: true }
}

fn ExecutionOptions::dry_run(self: ExecutionOptions) -> ExecutionOptions {
  ExecutionOptions::{ ..self, dry_run: true }
}

// ============ 任务路由器 ============

struct TaskRouter {
  context_manager: ContextManager
  spec_executor: SpecExecutor
  wave_executor: WaveExecutor
  quick_dir: String
}

fn TaskRouter::new(
  context_manager: ContextManager,
  spec_executor: SpecExecutor,
  wave_executor: WaveExecutor
) -> TaskRouter {
  TaskRouter::{
    context_manager: context_manager,
    spec_executor: spec_executor,
    wave_executor: wave_executor,
    quick_dir: ".planning/quick/",
  }
}

// 主入口：根据选项路由到对应流程
fn TaskRouter::run(
  self: TaskRouter,
  description: String,
  options: ExecutionOptions
) -> TaskRouterResult {
  let start_time = now_ms()

  log_info("═══════════════════════════════════════")
  log_info("XiaoClaw Task Runner")
  log_info("Mode: \(mode_to_string(options.mode))")
  log_info("Task: \(description)")
  log_info("═══════════════════════════════════════")

  // 自动判断模式
  let actual_mode = if options.mode == Auto {
    self.detect_mode(description)
  } else {
    options.mode
  }

  let result = match actual_mode {
    Fast => self.run_fast(description, options),
    Quick => self.run_quick(description, options),
    Full => self.run_full(description, options),
    Auto => self.run_quick(description, options),  // fallback
  }

  let duration = now_ms() - start_time

  log_info("═══════════════════════════════════════")
  log_info("Done in \(duration)ms")
  log_info("═══════════════════════════════════════")

  result
}

// 自动检测模式
fn TaskRouter::detect_mode(self: TaskRouter, description: String) -> ExecutionMode {
  let word_count = description.split(" ").length()
  let has_complex_keywords = description.contains("重构") ||
    description.contains("架构") ||
    description.contains("系统") ||
    description.contains("refactor") ||
    description.contains("architecture")

  if word_count <= 5 && !has_complex_keywords {
    Fast
  } else if word_count <= 20 && !has_complex_keywords {
    Quick
  } else {
    Full
  }
}

// ============ Fast 模式（极速）============
// 完全跳过规划，直接执行
// 适合：改个配置、加条日志、小修小补

fn TaskRouter::run_fast(
  self: TaskRouter,
  description: String,
  options: ExecutionOptions
) -> TaskRouterResult {
  log_info("⚡ Fast Mode: \(description)")

  // 直接构建最简 Spec
  let spec = TaskSpecBuilder::new(description)
    .goal(description)
    .context("Fast mode — no planning")
    .action("Execute directly: \(description)")
    .done("Task completed")
    .build()

  if options.dry_run {
    return TaskRouterResult::{
      mode: Fast,
      spec: Some(spec),
      wave_plan: None,
      success: true,
      summary: "Dry run: \(spec.to_markdown())",
      duration_ms: 0,
    }
  }

  // 直接执行
  let result = self.spec_executor.execute(spec, |s| {
    Ok("Fast executed: \(s.goal)")
  })

  TaskRouterResult::{
    mode: Fast,
    spec: Some(spec),
    wave_plan: None,
    success: result.status == Done,
    summary: result.summary,
    duration_ms: result.duration_ms,
  }
}

// ============ Quick 模式（快速）============
// 跳过 research，可选 discuss 和 verify
// 适合：中等复杂度任务

fn TaskRouter::run_quick(
  self: TaskRouter,
  description: String,
  options: ExecutionOptions
) -> TaskRouterResult {
  log_info("🚀 Quick Mode: \(description)")

  // Step 1: Discuss（可选）
  let context = if options.discuss {
    self.collect_context(description)
  } else {
    description
  }

  // Step 2: 构建 Spec
  let spec = self.build_spec_from_description(context, options)

  // 保存到 quick 目录
  let spec_path = "\(self.quick_dir)\(spec.id)-PLAN.md"
  write_file(spec_path, spec.to_markdown())
  log_info("Spec saved: \(spec_path)")

  if options.dry_run {
    return TaskRouterResult::{
      mode: Quick,
      spec: Some(spec),
      wave_plan: None,
      success: true,
      summary: "Dry run:\n\n\(spec.to_markdown())",
      duration_ms: 0,
    }
  }

  // Step 3: 执行
  let result = self.spec_executor.execute(spec, |s| {
    Ok("Quick executed: \(s.goal)")
  })

  // Step 4: Verify（可选）
  let verified = if options.verify {
    self.run_verification(spec, result)
  } else {
    true
  }

  TaskRouterResult::{
    mode: Quick,
    spec: Some(spec),
    wave_plan: None,
    success: result.status == Done && verified,
    summary: result.summary,
    duration_ms: result.duration_ms,
  }
}

// ============ Full 模式（完整）============
// discuss → research → plan → wave execute → verify → ship
// 适合：复杂功能、多文件改动

fn TaskRouter::run_full(
  self: TaskRouter,
  description: String,
  options: ExecutionOptions
) -> TaskRouterResult {
  log_info("🔬 Full Mode: \(description)")

  let start_time = now_ms()

  // Step 1: Discuss — 收集上下文
  log_info("Step 1/5: Discuss")
  let context = self.collect_context(description)

  // Step 2: Research（可选）
  let research = if options.research {
    log_info("Step 2/5: Research")
    self.run_research(description, context)
  } else {
    log_info("Step 2/5: Research (skipped)")
    ""
  }

  // Step 3: Plan — 构建 Wave 计划
  log_info("Step 3/5: Plan")
  let wave_plan = self.build_wave_plan(description, context, research)

  // 可视化计划
  log_info(wave_plan.visualize())

  if options.dry_run {
    return TaskRouterResult::{
      mode: Full,
      spec: None,
      wave_plan: Some(wave_plan),
      success: true,
      summary: "Dry run:\n\n\(wave_plan.visualize())",
      duration_ms: now_ms() - start_time,
    }
  }

  // Step 4: Execute — Wave 执行
  log_info("Step 4/5: Execute")
  let handlers = Map::new()  // 实际使用时注入 handlers
  let plan_result = self.wave_executor.execute_plan(wave_plan, handlers)

  // Step 5: Verify
  log_info("Step 5/5: Verify")
  let verified = if options.verify {
    plan_result.success
  } else {
    true
  }

  let duration = now_ms() - start_time

  TaskRouterResult::{
    mode: Full,
    spec: None,
    wave_plan: Some(wave_plan),
    success: plan_result.success && verified,
    summary: plan_result.summary(),
    duration_ms: duration,
  }
}

// ============ 辅助步骤 ============

// 收集上下文（Discuss 步骤）
fn TaskRouter::collect_context(self: TaskRouter, description: String) -> String {
  // 实际实现中会与用户交互
  // 这里返回增强的描述
  let context_questions = [
    "目标: \(description)",
    "约束: 保持 WASM 体积 < 5MB",
    "优先级: 功能完整性 > 性能",
  ]

  String::join(context_questions, "\n")
}

// 调研（Research 步骤）
fn TaskRouter::run_research(self: TaskRouter, description: String, context: String) -> String {
  log_info("Researching: \(description)")

  // 实际实现中会调用 AI 进行调研
  "Research findings for: \(description)\n- Best practices identified\n- Potential pitfalls noted"
}

// 从描述构建 Spec
fn TaskRouter::build_spec_from_description(
  self: TaskRouter,
  description: String,
  options: ExecutionOptions
) -> TaskSpec {
  TaskSpecBuilder::new(description)
    .goal(description)
    .context("Auto-generated from description")
    .action("Implement: \(description)")
    .verify("Implementation complete", "No errors")
    .done("Feature implemented and working")
    .build()
}

// 构建 Wave 计划
fn TaskRouter::build_wave_plan(
  self: TaskRouter,
  description: String,
  context: String,
  research: String
) -> WavePlan {
  // 简化实现：将任务拆分为 3 个 Wave
  let spec1 = TaskSpecBuilder::new("Setup: \(description)")
    .goal("准备工作和基础设置")
    .action("初始化必要的结构和配置")
    .done("基础设置完成")
    .build()

  let spec2a = TaskSpecBuilder::new("Implement Core: \(description)")
    .goal("实现核心功能")
    .action("编写主要业务逻辑")
    .done("核心功能实现完成")
    .build()

  let spec2b = TaskSpecBuilder::new("Implement Tests: \(description)")
    .goal("编写测试")
    .action("为核心功能编写单元测试")
    .done("测试覆盖率 > 80%")
    .build()

  let spec3 = TaskSpecBuilder::new("Integration: \(description)")
    .goal("集成和验证")
    .action("集成所有组件，运行完整测试")
    .done("所有测试通过，功能完整")
    .build()

  WavePlanBuilder::new(description)
    .add(spec1)
    .add_after(spec2a, [spec1.id])
    .add_after(spec2b, [spec1.id])
    .add_after(spec3, [spec2a.id, spec2b.id])
    .build()
}

// 运行验证
fn TaskRouter::run_verification(self: TaskRouter, spec: TaskSpec, result: SpecResult) -> Bool {
  log_info("Running verification for: \(spec.name)")
  result.status == Done
}

// ============ 结果结构 ============

struct TaskRouterResult {
  mode: ExecutionMode
  spec: TaskSpec?
  wave_plan: WavePlan?
  success: Bool
  summary: String
  duration_ms: Int
}

// ============ CLI 集成 ============

// 解析 CLI 参数为 ExecutionOptions
fn parse_execution_options(args: Array[String]) -> ExecutionOptions {
  let mut opts = ExecutionOptions::quick()

  for arg in args {
    match arg {
      "--fast" => opts = ExecutionOptions::fast(),
      "--quick" => opts = ExecutionOptions::quick(),
      "--full" => opts = ExecutionOptions::full(),
      "--discuss" => opts = opts.with_discuss(),
      "--research" => opts = opts.with_research(),
      "--verify" => opts = opts.with_verify(),
      "--dry-run" => opts = opts.dry_run(),
      "--verbose" => opts = ExecutionOptions::{ ..opts, verbose: true },
      _ => {}
    }
  }

  opts
}

// ============ 辅助函数 ============

fn mode_to_string(m: ExecutionMode) -> String {
  match m {
    Quick => "Quick"
    Full => "Full"
    Fast => "Fast"
    Auto => "Auto"
  }
}
