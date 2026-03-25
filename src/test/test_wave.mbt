// XiaoClaw - Wave Executor 测试
// 覆盖：DAG 构建、拓扑排序、Wave 分配、循环依赖检测

// ============ 辅助：创建测试用 TaskSpec ============

fn make_spec(id : String, name : String) -> TaskSpec {
  TaskSpec::{
    id,
    name,
    goal: "测试目标",
    context: "",
    actions: [],
    verify_conditions: [],
    done_criteria: [],
    priority: Normal,
    tags: [],
    created_at: now(),
  }
}

// ============ WavePlanBuilder 测试 ============

fn test_wave_single_node_no_deps() -> TestResult {
  let builder = WavePlanBuilder::new("单节点计划")
  let spec = make_spec("t1", "任务1")
  let result = builder.add(spec).build()

  match result {
    Ok(plan) => {
      let passed = plan.waves.length() == 1 &&
        plan.waves[0].nodes.length() == 1 &&
        plan.total_nodes == 1
      { name: "Wave::单节点无依赖 → 1个Wave", passed, message: if passed { "ok" } else { "waves=\(plan.waves.length())" }, duration: 0 }
    }
    Err(e) => { name: "Wave::单节点无依赖 → 1个Wave", passed: false, message: "构建失败: \(e)", duration: 0 }
  }
}

fn test_wave_two_independent_nodes_same_wave() -> TestResult {
  let builder = WavePlanBuilder::new("两个独立节点")
  let s1 = make_spec("t1", "任务1")
  let s2 = make_spec("t2", "任务2")

  let result = builder.add(s1).add(s2).build()

  match result {
    Ok(plan) => {
      // 两个独立节点应该在同一个 Wave 里并行
      let passed = plan.waves.length() == 1 &&
        plan.waves[0].nodes.length() == 2 &&
        plan.waves[0].parallel == true
      { name: "Wave::两个独立节点 → 同一Wave并行", passed, message: if passed { "ok" } else { "waves=\(plan.waves.length()) nodes=\(plan.waves[0].nodes.length())" }, duration: 0 }
    }
    Err(e) => { name: "Wave::两个独立节点 → 同一Wave并行", passed: false, message: e, duration: 0 }
  }
}

fn test_wave_linear_dependency_two_waves() -> TestResult {
  // t1 → t2（线性依赖）→ 应该是 Wave0: [t1], Wave1: [t2]
  let builder = WavePlanBuilder::new("线性依赖")
  let s1 = make_spec("t1", "任务1")
  let s2 = make_spec("t2", "任务2")

  let result = builder.add(s1).add_after(s2, ["t1"]).build()

  match result {
    Ok(plan) => {
      let passed = plan.waves.length() == 2 &&
        plan.waves[0].nodes.length() == 1 &&
        plan.waves[1].nodes.length() == 1 &&
        plan.waves[0].nodes[0].spec.id == "t1" &&
        plan.waves[1].nodes[0].spec.id == "t2"
      { name: "Wave::线性依赖 → 2个Wave", passed, message: if passed { "ok" } else { "waves=\(plan.waves.length())" }, duration: 0 }
    }
    Err(e) => { name: "Wave::线性依赖 → 2个Wave", passed: false, message: e, duration: 0 }
  }
}

fn test_wave_diamond_dependency() -> TestResult {
  // 菱形依赖：t1 → t2, t3 → t4
  //   Wave0: [t1]
  //   Wave1: [t2, t3]  (并行)
  //   Wave2: [t4]
  let builder = WavePlanBuilder::new("菱形依赖")
  let s1 = make_spec("t1", "根节点")
  let s2 = make_spec("t2", "左分支")
  let s3 = make_spec("t3", "右分支")
  let s4 = make_spec("t4", "汇聚节点")

  let result = builder
    .add(s1)
    .add_after(s2, ["t1"])
    .add_after(s3, ["t1"])
    .add_after(s4, ["t2", "t3"])
    .build()

  match result {
    Ok(plan) => {
      let passed = plan.waves.length() == 3 &&
        plan.waves[0].nodes.length() == 1 &&  // t1
        plan.waves[1].nodes.length() == 2 &&  // t2, t3 并行
        plan.waves[2].nodes.length() == 1 &&  // t4
        plan.waves[1].parallel == true
      { name: "Wave::菱形依赖 → 3个Wave（中间并行）", passed, message: if passed { "ok" } else { "waves=\(plan.waves.length())" }, duration: 0 }
    }
    Err(e) => { name: "Wave::菱形依赖 → 3个Wave（中间并行）", passed: false, message: e, duration: 0 }
  }
}

fn test_wave_circular_dependency_returns_error() -> TestResult {
  // 🔴 Fix #12 验证：循环依赖应该返回 Err，不是静默失败
  // t1 → t2 → t1（循环）
  let builder = WavePlanBuilder::new("循环依赖")
  let s1 = make_spec("t1", "节点1")
  let s2 = make_spec("t2", "节点2")

  // 手动构造循环：t1 依赖 t2，t2 依赖 t1
  let result = builder
    .add_after(s1, ["t2"])
    .add_after(s2, ["t1"])
    .build()

  match result {
    Ok(_) => { name: "Wave::循环依赖 → 返回 Err（Fix #12）", passed: false, message: "应该返回 Err 但返回了 Ok", duration: 0 }
    Err(e) => {
      let passed = e.contains("Circular") || e.contains("circular") || e.contains("循环")
      { name: "Wave::循环依赖 → 返回 Err（Fix #12）", passed, message: if passed { "ok: \(e)" } else { "错误信息不包含循环依赖说明: \(e)" }, duration: 0 }
    }
  }
}

fn test_wave_total_nodes_count() -> TestResult {
  let builder = WavePlanBuilder::new("节点计数")
  let s1 = make_spec("t1", "任务1")
  let s2 = make_spec("t2", "任务2")
  let s3 = make_spec("t3", "任务3")

  let result = builder.add(s1).add(s2).add_after(s3, ["t1"]).build()

  match result {
    Ok(plan) => {
      let passed = plan.total_nodes == 3
      { name: "Wave::total_nodes 计数正确", passed, message: if passed { "ok" } else { "total_nodes=\(plan.total_nodes)" }, duration: 0 }
    }
    Err(e) => { name: "Wave::total_nodes 计数正确", passed: false, message: e, duration: 0 }
  }
}

fn test_wave_single_node_not_parallel() -> TestResult {
  // 单节点 Wave 不应该标记为 parallel
  let builder = WavePlanBuilder::new("单节点并行标记")
  let s1 = make_spec("t1", "任务1")

  let result = builder.add(s1).build()

  match result {
    Ok(plan) => {
      let passed = plan.waves[0].parallel == false
      { name: "Wave::单节点 Wave 不标记为 parallel", passed, message: if passed { "ok" } else { "单节点 Wave 不应该是 parallel" }, duration: 0 }
    }
    Err(e) => { name: "Wave::单节点 Wave 不标记为 parallel", passed: false, message: e, duration: 0 }
  }
}

fn test_wave_visualize_output() -> TestResult {
  let builder = WavePlanBuilder::new("可视化测试")
  let s1 = make_spec("t1", "任务1")
  let s2 = make_spec("t2", "任务2")

  let result = builder.add(s1).add_after(s2, ["t1"]).build()

  match result {
    Ok(plan) => {
      let viz = plan.visualize()
      let passed = viz.contains("WAVE") && viz.contains("任务1") && viz.contains("任务2")
      { name: "Wave::visualize 输出包含关键信息", passed, message: if passed { "ok" } else { "visualize 输出不完整" }, duration: 0 }
    }
    Err(e) => { name: "Wave::visualize 输出包含关键信息", passed: false, message: e, duration: 0 }
  }
}

// ============ 测试套件注册 ============

fn wave_test_suite() -> TestSuite {
  TestSuite::{
    name: "Wave Executor",
    tests: [
      test_wave_single_node_no_deps,
      test_wave_two_independent_nodes_same_wave,
      test_wave_linear_dependency_two_waves,
      test_wave_diamond_dependency,
      test_wave_circular_dependency_returns_error,
      test_wave_total_nodes_count,
      test_wave_single_node_not_parallel,
      test_wave_visualize_output,
    ],
    setup: None,
    teardown: None,
  }
}
