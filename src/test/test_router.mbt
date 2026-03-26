// XiaoClaw - Task Router 测试
// 覆盖：ExecutionOptions、detect_mode、Fast/Quick/Full 模式、dry_run、parse_options

// ============ ExecutionOptions 测试 ============

fn test_options_quick_defaults() -> TestResult {
  let opts = ExecutionOptions::quick()
  let passed = opts.mode == Quick &&
    opts.discuss == false &&
    opts.research == false &&
    opts.verify == false &&
    opts.dry_run == false

  { name: "ExecutionOptions::quick 默认值", passed, message: if passed { "ok" } else { "默认值不正确" }, duration: 0 }
}

fn test_options_full_defaults() -> TestResult {
  let opts = ExecutionOptions::full()
  let passed = opts.mode == Full &&
    opts.discuss == true &&
    opts.research == true &&
    opts.verify == true

  { name: "ExecutionOptions::full 默认值", passed, message: if passed { "ok" } else { "full 模式默认值不正确" }, duration: 0 }
}

fn test_options_fast_defaults() -> TestResult {
  let opts = ExecutionOptions::fast()
  let passed = opts.mode == Fast &&
    opts.discuss == false &&
    opts.verify == false

  { name: "ExecutionOptions::fast 默认值", passed, message: if passed { "ok" } else { "fast 模式默认值不正确" }, duration: 0 }
}

fn test_options_with_flags() -> TestResult {
  let opts = ExecutionOptions::quick()
    .with_discuss()
    .with_research()
    .with_verify()
    .with_dry_run()

  let passed = opts.discuss == true &&
    opts.research == true &&
    opts.verify == true &&
    opts.dry_run == true &&
    opts.mode == Quick  // mode 不变

  { name: "ExecutionOptions::flags 叠加", passed, message: if passed { "ok" } else { "flags 叠加不正确" }, duration: 0 }
}

// ============ detect_mode 测试 ============

fn test_detect_mode_short_simple() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let spec_exec = SpecExecutor::new(ctx)
  let wave_exec = WaveExecutor::new(ctx, spec_exec)
  let router = TaskRouter::new(ctx, spec_exec, wave_exec)

  // 短描述 → Fast
  let mode = router.detect_mode("加条日志")
  let passed = mode == Fast

  { name: "detect_mode::短描述 → Fast", passed, message: if passed { "ok" } else { "mode=\(mode_to_string(mode))" }, duration: 0 }
}

fn test_detect_mode_medium() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let spec_exec = SpecExecutor::new(ctx)
  let wave_exec = WaveExecutor::new(ctx, spec_exec)
  let router = TaskRouter::new(ctx, spec_exec, wave_exec)

  // 中等描述 → Quick
  let mode = router.detect_mode("给飞书通道添加一个发送图片的功能，支持 URL 和本地路径")
  let passed = mode == Quick

  { name: "detect_mode::中等描述 → Quick", passed, message: if passed { "ok" } else { "mode=\(mode_to_string(mode))" }, duration: 0 }
}

fn test_detect_mode_complex_keyword() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let spec_exec = SpecExecutor::new(ctx)
  let wave_exec = WaveExecutor::new(ctx, spec_exec)
  let router = TaskRouter::new(ctx, spec_exec, wave_exec)

  // 含复杂关键词 → Full
  let mode = router.detect_mode("重构整个系统架构")
  let passed = mode == Full

  { name: "detect_mode::复杂关键词 → Full", passed, message: if passed { "ok" } else { "mode=\(mode_to_string(mode))" }, duration: 0 }
}

// ============ Fast 模式测试 ============

fn test_router_fast_mode_success() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let spec_exec = SpecExecutor::new(ctx)
  let wave_exec = WaveExecutor::new(ctx, spec_exec)
  let router = TaskRouter::new(ctx, spec_exec, wave_exec)

  let result = router.run("加条日志", ExecutionOptions::fast())

  let passed = result.mode == Fast && result.success == true

  { name: "Router::Fast 模式执行成功", passed, message: if passed { "ok" } else { "success=\(result.success)" }, duration: 0 }
}

fn test_router_fast_dry_run() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let spec_exec = SpecExecutor::new(ctx)
  let wave_exec = WaveExecutor::new(ctx, spec_exec)
  let router = TaskRouter::new(ctx, spec_exec, wave_exec)

  let result = router.run("加条日志", ExecutionOptions::fast().with_dry_run())

  let passed = result.mode == Fast &&
    result.success == true &&
    result.summary.contains("Dry run")

  { name: "Router::Fast dry_run 返回计划不执行", passed, message: if passed { "ok" } else { "summary 不含 Dry run" }, duration: 0 }
}

// ============ Quick 模式测试 ============

fn test_router_quick_mode_success() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let spec_exec = SpecExecutor::new(ctx)
  let wave_exec = WaveExecutor::new(ctx, spec_exec)
  let router = TaskRouter::new(ctx, spec_exec, wave_exec)

  let result = router.run("添加飞书消息功能", ExecutionOptions::quick())

  let passed = result.mode == Quick && result.success == true && result.spec.is_some()

  { name: "Router::Quick 模式执行成功", passed, message: if passed { "ok" } else { "success=\(result.success)" }, duration: 0 }
}

fn test_router_quick_dry_run() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let spec_exec = SpecExecutor::new(ctx)
  let wave_exec = WaveExecutor::new(ctx, spec_exec)
  let router = TaskRouter::new(ctx, spec_exec, wave_exec)

  let result = router.run("添加功能", ExecutionOptions::quick().with_dry_run())

  let passed = result.success == true &&
    result.summary.contains("Dry run") &&
    result.spec.is_some()

  { name: "Router::Quick dry_run 返回 Spec 不执行", passed, message: if passed { "ok" } else { "dry_run 不正确" }, duration: 0 }
}

// ============ Full 模式测试 ============

fn test_router_full_mode_builds_wave_plan() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let spec_exec = SpecExecutor::new(ctx)
  let wave_exec = WaveExecutor::new(ctx, spec_exec)
  let router = TaskRouter::new(ctx, spec_exec, wave_exec)

  let result = router.run("重构整个系统架构", ExecutionOptions::full().with_dry_run())

  // dry_run 下应该有 wave_plan
  let passed = result.wave_plan.is_some() && result.summary.contains("Dry run")

  { name: "Router::Full dry_run 生成 Wave 计划", passed, message: if passed { "ok" } else { "wave_plan=\(result.wave_plan.is_some())" }, duration: 0 }
}

fn test_router_full_wave_plan_has_4_nodes() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let spec_exec = SpecExecutor::new(ctx)
  let wave_exec = WaveExecutor::new(ctx, spec_exec)
  let router = TaskRouter::new(ctx, spec_exec, wave_exec)

  let result = router.run("重构系统", ExecutionOptions::full().with_dry_run())

  match result.wave_plan {
    Some(plan) => {
      // 默认 wave plan 有 4 个节点（Setup, Core, Tests, Integration）
      let passed = plan.total_nodes == 4 && plan.waves.length() == 3
      { name: "Router::Full Wave 计划有 4 节点 3 Wave", passed, message: if passed { "ok" } else { "nodes=\(plan.total_nodes) waves=\(plan.waves.length())" }, duration: 0 }
    }
    None => { name: "Router::Full Wave 计划有 4 节点 3 Wave", passed: false, message: "wave_plan 为 None", duration: 0 }
  }
}

// ============ Auto 模式测试 ============

fn test_router_auto_mode_routes_correctly() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let spec_exec = SpecExecutor::new(ctx)
  let wave_exec = WaveExecutor::new(ctx, spec_exec)
  let router = TaskRouter::new(ctx, spec_exec, wave_exec)

  // Auto 模式 + 短描述 → 应该走 Fast
  let result = router.run("改个配置", { ..ExecutionOptions::quick(), mode: Auto })

  // Fast 模式下 wave_plan 为 None
  let passed = result.wave_plan.is_none() && result.success == true

  { name: "Router::Auto 模式自动路由", passed, message: if passed { "ok" } else { "路由不正确" }, duration: 0 }
}

// ============ parse_execution_options 测试 ============

fn test_parse_options_fast_flag() -> TestResult {
  let opts = parse_execution_options(["--fast"])
  let passed = opts.mode == Fast

  { name: "parse_options::--fast 标志", passed, message: if passed { "ok" } else { "mode=\(mode_to_string(opts.mode))" }, duration: 0 }
}

fn test_parse_options_full_flag() -> TestResult {
  let opts = parse_execution_options(["--full"])
  let passed = opts.mode == Full && opts.discuss == true && opts.verify == true

  { name: "parse_options::--full 标志", passed, message: if passed { "ok" } else { "full 标志解析不正确" }, duration: 0 }
}

fn test_parse_options_combined_flags() -> TestResult {
  let opts = parse_execution_options(["--quick", "--discuss", "--verify", "--dry-run"])
  let passed = opts.mode == Quick &&
    opts.discuss == true &&
    opts.verify == true &&
    opts.dry_run == true

  { name: "parse_options::组合标志", passed, message: if passed { "ok" } else { "组合标志解析不正确" }, duration: 0 }
}

fn test_parse_options_unknown_flags_ignored() -> TestResult {
  let opts = parse_execution_options(["--unknown", "--also-unknown"])
  // 未知标志应该被忽略，使用默认值
  let passed = opts.mode == Quick

  { name: "parse_options::未知标志被忽略", passed, message: if passed { "ok" } else { "未知标志影响了结果" }, duration: 0 }
}

// ============ 测试套件注册 ============

fn router_test_suite() -> TestSuite {
  TestSuite::{
    name: "Task Router",
    tests: [
      test_options_quick_defaults,
      test_options_full_defaults,
      test_options_fast_defaults,
      test_options_with_flags,
      test_detect_mode_short_simple,
      test_detect_mode_medium,
      test_detect_mode_complex_keyword,
      test_router_fast_mode_success,
      test_router_fast_dry_run,
      test_router_quick_mode_success,
      test_router_quick_dry_run,
      test_router_full_mode_builds_wave_plan,
      test_router_full_wave_plan_has_4_nodes,
      test_router_auto_mode_routes_correctly,
      test_parse_options_fast_flag,
      test_parse_options_full_flag,
      test_parse_options_combined_flags,
      test_parse_options_unknown_flags_ignored,
    ],
    setup: None,
    teardown: None,
  }
}
