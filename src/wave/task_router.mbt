// XiaoClaw Quick/Full Mode
// 快速模式 + 完整模式
// 灵感来自 GSD 的 /gsd:quick 和 /gsd:new-project 设计

// 执行模式
enum ExecutionMode {
  Quick  // 快速：跳过规划，直接执行
  Full   // 完整：discuss → plan → execute → verify → ship
  Fast   // 极速：完全跳过规划和验证
  Auto   // 自动：根据任务复杂度选择
} derive(Eq, Show)

// 执行选项（flags 可组合）
struct ExecutionOptions {
  mode       : ExecutionMode
  discuss    : Bool
  research   : Bool
  verify     : Bool
  plan_check : Bool
  dry_run    : Bool
  verbose    : Bool
}

fn ExecutionOptions::quick() -> ExecutionOptions {
  { mode: Quick, discuss: false, research: false, verify: false, plan_check: false, dry_run: false, verbose: false }
}

fn ExecutionOptions::full() -> ExecutionOptions {
  { mode: Full, discuss: true, research: true, verify: true, plan_check: true, dry_run: false, verbose: true }
}

fn ExecutionOptions::fast() -> ExecutionOptions {
  { mode: Fast, discuss: false, research: false, verify: false, plan_check: false, dry_run: false, verbose: false }
}

fn ExecutionOptions::with_discuss(self : ExecutionOptions) -> ExecutionOptions {
  { ..self, discuss: true }
}

fn ExecutionOptions::with_research(self : ExecutionOptions) -> ExecutionOptions {
  { ..self, research: true }
}

fn ExecutionOptions::with_verify(self : ExecutionOptions) -> ExecutionOptions {
  { ..self, verify: true }
}

fn ExecutionOptions::with_dry_run(self : ExecutionOptions) -> ExecutionOptions {
  { ..self, dry_run: true }
}

// ============ 任务路由器 ============

struct TaskRouter {
  context_manager : ContextManager
  spec_executor   : SpecExecutor
  wave_executor   : WaveExecutor
  quick_dir       : String
}

fn TaskRouter::new(
  context_manager : ContextManager,
  spec_executor   : SpecExecutor,
  wave_executor   : WaveExecutor
) -> TaskRouter {
  { context_manager, spec_executor, wave_executor, quick_dir: ".planning/quick/" }
}

fn TaskRouter::run(
  self        : TaskRouter,
  description : String,
  options     : ExecutionOptions
) -> TaskRouterResult {
  let start_time = now_ms()

  log_info("═══════════════════════════════════════")
  log_info("XiaoClaw Task Runner")
  log_info("Mode: \(mode_to_string(options.mode))")
  log_info("Task: \(description)")
  log_info("═══════════════════════════════════════")

  // 🟡 Fix #14: Auto 模式用 detect_mode 决定，不再有死代码分支
  let actual_mode = if options.mode == Auto {
    self.detect_mode(description)
  } else {
    options.mode
  }

  let result = match actual_mode {
    Fast  => self.run_fast(description, options)
    Quick => self.run_quick(description, options)
    Full  => self.run_full(description, options)
    Auto  => self.run_quick(description, options)  // detect_mode 不返回 Auto，此分支为安全 fallback
  }

  let duration = now_ms() - start_time
  log_info("Done in \(duration)ms")

  result
}

// 🟡 Fix #12: 不依赖 .split()，用字符计数估算复杂度
fn TaskRouter::detect_mode(self : TaskRouter, description : String) -> ExecutionMode {
  let char_count = description.length()
  let has_complex = description.contains("重构") ||
    description.contains("架构") ||
    description.contains("系统") ||
    description.contains("refactor") ||
    description.contains("architecture")

  if char_count <= 20 && not(has_complex) {
    Fast
  } else if char_count <= 100 && not(has_complex) {
    Quick
  } else {
    Full
  }
}

// ============ Fast 模式 ============

fn TaskRouter::run_fast(
  self        : TaskRouter,
  description : String,
  options     : ExecutionOptions
) -> TaskRouterResult {
  log_info("⚡ Fast Mode: \(description)")

  let spec = TaskSpecBuilder::new(description)
    .goal(description)
    .context("Fast mode — no planning")
    .action("Execute directly: \(description)")
    .done("Task completed")
    .build()

  if options.dry_run {
    return {
      mode: Fast, spec: Some(spec), wave_plan: None,
      success: true, summary: "Dry run:\n\n\(spec.to_markdown())", duration_ms: 0,
    }
  }

  let result = self.spec_executor.execute(spec, fn(s) { Ok("Fast executed: \(s.goal)") })

  {
    mode: Fast, spec: Some(spec), wave_plan: None,
    success: result.status == Done, summary: result.summary, duration_ms: result.duration_ms,
  }
}

// ============ Quick 模式 ============

fn TaskRouter::run_quick(
  self        : TaskRouter,
  description : String,
  options     : ExecutionOptions
) -> TaskRouterResult {
  log_info("🚀 Quick Mode: \(description)")

  let context = if options.discuss {
    self.collect_context(description)
  } else {
    description
  }

  let spec = self.build_spec_from_description(context, options)

  let spec_path = "\(self.quick_dir)\(spec.id)-PLAN.md"
  match try_write_file(spec_path, spec.to_markdown()) {
    Ok(_)  => log_info("Spec saved: \(spec_path)")
    Err(e) => log_warn("Could not save spec: \(e)")
  }

  if options.dry_run {
    return {
      mode: Quick, spec: Some(spec), wave_plan: None,
      success: true, summary: "Dry run:\n\n\(spec.to_markdown())", duration_ms: 0,
    }
  }

  let result = self.spec_executor.execute(spec, fn(s) { Ok("Quick executed: \(s.goal)") })

  let verified = if options.verify {
    self.run_verification(spec, result)
  } else {
    true
  }

  {
    mode: Quick, spec: Some(spec), wave_plan: None,
    success: result.status == Done && verified, summary: result.summary, duration_ms: result.duration_ms,
  }
}

// ============ Full 模式 ============

fn TaskRouter::run_full(
  self        : TaskRouter,
  description : String,
  options     : ExecutionOptions
) -> TaskRouterResult {
  log_info("🔬 Full Mode: \(description)")
  let start_time = now_ms()

  log_info("Step 1/5: Discuss")
  let context = self.collect_context(description)

  let research = if options.research {
    log_info("Step 2/5: Research")
    self.run_research(description, context)
  } else {
    log_info("Step 2/5: Research (skipped)")
    ""
  }

  log_info("Step 3/5: Plan")
  // 🔴 Fix #10+11: build() 返回 Result，必须处理错误
  let wave_plan_result = self.build_wave_plan(description, context, research)

  match wave_plan_result {
    Err(e) => {
      log_error("Wave plan build failed: \(e)")
      return {
        mode: Full, spec: None, wave_plan: None,
        success: false, summary: "Plan failed: \(e)", duration_ms: now_ms() - start_time,
      }
    }
    Ok(wave_plan) => {
      log_info(wave_plan.visualize())

      if options.dry_run {
        return {
          mode: Full, spec: None, wave_plan: Some(wave_plan),
          success: true, summary: "Dry run:\n\n\(wave_plan.visualize())", duration_ms: now_ms() - start_time,
        }
      }

      log_info("Step 4/5: Execute")
      // 🟡 Fix #13: 明确记录 handlers 为空的警告
      let handlers : Map[String, (TaskSpec) -> Result[String, String]] = {}
      if handlers.size() == 0 {
        log_warn("No handlers registered — nodes will use default handler")
      }
      let plan_result = self.wave_executor.execute_plan(wave_plan, handlers)

      log_info("Step 5/5: Verify")
      let verified = if options.verify { plan_result.success } else { true }

      let duration = now_ms() - start_time
      {
        mode: Full, spec: None, wave_plan: Some(wave_plan),
        success: plan_result.success && verified, summary: plan_result.summary(), duration_ms: duration,
      }
    }
  }
}

// ============ 辅助步骤 ============

fn TaskRouter::collect_context(self : TaskRouter, description : String) -> String {
  let lines : Array[String] = [
    "目标: \(description)",
    "约束: 保持 WASM 体积 < 5MB",
    "优先级: 功能完整性 > 性能",
  ]
  lines.join("\n")
}

fn TaskRouter::run_research(self : TaskRouter, description : String, _context : String) -> String {
  log_info("Researching: \(description)")
  "Research findings for: \(description)\n- Best practices identified\n- Potential pitfalls noted"
}

fn TaskRouter::build_spec_from_description(
  self        : TaskRouter,
  description : String,
  _options    : ExecutionOptions
) -> TaskSpec {
  TaskSpecBuilder::new(description)
    .goal(description)
    .context("Auto-generated from description")
    .action("Implement: \(description)")
    .verify("Implementation complete", "No errors")
    .done("Feature implemented and working")
    .build()
}

// 🔴 Fix #10: 返回 Result，传播循环依赖错误
fn TaskRouter::build_wave_plan(
  self        : TaskRouter,
  description : String,
  _context    : String,
  _research   : String
) -> Result[WavePlan, String] {
  let spec1 = TaskSpecBuilder::new("Setup")
    .goal("准备工作和基础设置")
    .action("初始化必要的结构和配置")
    .done("基础设置完成")
    .build()

  let spec2a = TaskSpecBuilder::new("Implement Core")
    .goal("实现核心功能")
    .action("编写主要业务逻辑")
    .done("核心功能实现完成")
    .build()

  let spec2b = TaskSpecBuilder::new("Implement Tests")
    .goal("编写测试")
    .action("为核心功能编写单元测试")
    .done("测试覆盖率 > 80%")
    .build()

  let spec3 = TaskSpecBuilder::new("Integration")
    .goal("集成和验证: \(description)")
    .action("集成所有组件，运行完整测试")
    .done("所有测试通过，功能完整")
    .build()

  WavePlanBuilder::new(description)
    .add(spec1)
    .add_after(spec2a, [spec1.id])
    .add_after(spec2b, [spec1.id])
    .add_after(spec3, [spec2a.id, spec2b.id])
    .build()  // 返回 Result[WavePlan, String]
}

fn TaskRouter::run_verification(self : TaskRouter, _spec : TaskSpec, result : SpecResult) -> Bool {
  result.status == Done
}

// ============ 结果结构 ============

struct TaskRouterResult {
  mode        : ExecutionMode
  spec        : TaskSpec?
  wave_plan   : WavePlan?
  success     : Bool
  summary     : String
  duration_ms : Int
}

// ============ CLI 参数解析 ============

// 🟢 Fix #15: 用 if/else if 链代替 match String（MoonBit 兼容）
fn parse_execution_options(args : Array[String]) -> ExecutionOptions {
  let mut opts = ExecutionOptions::quick()

  for arg in args {
    if arg == "--fast" {
      opts = ExecutionOptions::fast()
    } else if arg == "--quick" {
      opts = ExecutionOptions::quick()
    } else if arg == "--full" {
      opts = ExecutionOptions::full()
    } else if arg == "--discuss" {
      opts = opts.with_discuss()
    } else if arg == "--research" {
      opts = opts.with_research()
    } else if arg == "--verify" {
      opts = opts.with_verify()
    } else if arg == "--dry-run" {
      opts = opts.with_dry_run()
    } else if arg == "--verbose" {
      opts = { ..opts, verbose: true }
    }
  }

  opts
}

// ============ 辅助函数 ============

fn mode_to_string(m : ExecutionMode) -> String {
  match m {
    Quick => "Quick"
    Full  => "Full"
    Fast  => "Fast"
    Auto  => "Auto"
  }
}
