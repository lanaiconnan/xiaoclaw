// XiaoClaw - Benchmark 测试
// 覆盖：BenchmarkResult、MetricsCollector、类型转换、边界情况

// ============ BenchmarkResult 测试 ============

fn test_benchmark_result_new() -> TestResult {
  let r = BenchmarkResult::new("测试", 10)
  let passed = r.name == "测试" &&
    r.iterations == 10 &&
    r.total_time_ms == 0.0 &&
    r.avg_time_ms == 0.0

  { name: "BenchmarkResult::new 默认值正确", passed, message: if passed { "ok" } else { "默认值不正确" }, duration: 0 }
}

fn test_benchmark_result_compare_pass() -> TestResult {
  let r = BenchmarkResult::new("快", 100)
  // 修改 avg_time_ms 模拟快速结果
  let mut fast_r = r
  fast_r.avg_time_ms = 50.0

  let target = BenchmarkTarget::default()  // startup_time_ms: 100
  let passed = fast_r.compare(target) == true

  { name: "BenchmarkResult::compare 通过", passed, message: if passed { "ok" } else { "50ms < 100ms 应该通过" }, duration: 0 }
}

fn test_benchmark_result_compare_fail() -> TestResult {
  let mut slow_r = BenchmarkResult::new("慢", 100)
  slow_r.avg_time_ms = 200.0

  let target = BenchmarkTarget::default()  // startup_time_ms: 100
  let passed = slow_r.compare(target) == false

  { name: "BenchmarkResult::compare 失败", passed, message: if passed { "ok" } else { "200ms < 100ms 不应该通过" }, duration: 0 }
}

fn test_benchmark_result_print() -> TestResult {
  // 🔴 Fix #8 验证：print 不 panic
  let r = BenchmarkResult::new("打印测试", 5)
  let _ = r.print()  // 不应该 panic
  let passed = true

  { name: "BenchmarkResult::print 不 panic", passed, message: if passed { "ok" } else { "print panic 了" }, duration: 0 }
}

fn test_benchmark_target_default() -> TestResult {
  let t = BenchmarkTarget::default()
  let passed = t.name == "XiaoClaw" &&
    t.wasm_size_kb == 5120 &&
    t.startup_time_ms == 100.0 &&
    t.memory_usage_kb == 51200

  { name: "BenchmarkTarget::default 值正确", passed, message: if passed { "ok" } else { "默认值不正确" }, duration: 0 }
}

// ============ MetricsCollector 测试 ============

fn test_metrics_collector_new() -> TestResult {
  let c = MetricsCollector::new()
  let passed = c.samples.length() == 0

  { name: "MetricsCollector::new 初始为空", passed, message: if passed { "ok" } else { "samples 不为空" }, duration: 0 }
}

fn test_metrics_collector_average_empty() -> TestResult {
  let c = MetricsCollector::new()
  let avg = c.average()

  let passed = avg.startup_time_ms == 0.0 &&
    avg.wasm_size_kb == 0 &&
    avg.memory_usage_kb == 0

  { name: "MetricsCollector::average 空集不 panic", passed, message: if passed { "ok" } else { "空集 panic 了" }, duration: 0 }
}

fn test_metrics_collector_average_single() -> TestResult {
  let c = MetricsCollector::new()
  c.add({ startup_time_ms: 45.0, wasm_size_kb: 4800, memory_usage_kb: 12500, cold_start_ms: 45.0, warm_start_ms: 8.0 })
  let avg = c.average()

  // 单个样本，平均值 = 本身
  let passed = avg.startup_time_ms == 45.0 &&
    avg.wasm_size_kb == 4800 &&
    avg.memory_usage_kb == 12500

  { name: "MetricsCollector::average 单样本", passed, message: if passed { "ok" } else { "单样本平均值不正确" }, duration: 0 }
}

fn test_metrics_collector_average_multiple() -> TestResult {
  let c = MetricsCollector::new()
  c.add({ startup_time_ms: 40.0, wasm_size_kb: 4800, memory_usage_kb: 12000, cold_start_ms: 40.0, warm_start_ms: 7.0 })
  c.add({ startup_time_ms: 50.0, wasm_size_kb: 4800, memory_usage_kb: 13000, cold_start_ms: 50.0, warm_start_ms: 9.0 })
  let avg = c.average()

  // 🔴 Fix #3 验证：整数除法修复
  // startup: (40+50)/2 = 45.0
  // memory: (12000+13000)/2 = 12500 (浮点除法)
  let passed = avg.startup_time_ms == 45.0 &&
    avg.wasm_size_kb == 4800 &&
    avg.memory_usage_kb == 12500

  { name: "MetricsCollector::average 多样本浮点除法（Fix #3）", passed, message: if passed { "ok" } else { "浮点除法不正确" }, duration: 0 }
}

// ============ 类型转换测试 ============

fn test_int_to_f64() -> TestResult {
  let passed = int_to_f64(0) == 0.0 &&
    int_to_f64(42) == 42.0 &&
    int_to_f64(-1) == -1.0

  { name: "int_to_f64 转换正确", passed, message: if passed { "ok" } else { "int_to_f64 不正确" }, duration: 0 }
}

fn test_f64_to_int() -> TestResult {
  let passed = f64_to_int(0.0) == 0 &&
    f64_to_int(42.9) == 42 &&
    f64_to_int(3.14) == 3

  { name: "f64_to_int 截断转换正确", passed, message: if passed { "ok" } else { "f64_to_int 不正确" }, duration: 0 }
}

fn test_now_ms_f64() -> TestResult {
  let t = now_ms_f64()
  let passed = t > 0.0

  { name: "now_ms_f64 返回正数", passed, message: if passed { "ok" } else { "返回了非正数" }, duration: 0 }
}

fn test_performance_metrics_print() -> TestResult {
  let m = { startup_time_ms: 45.0, wasm_size_kb: 4800, memory_usage_kb: 12500, cold_start_ms: 45.0, warm_start_ms: 8.0 }
  let t = BenchmarkTarget::default()
  let _ = m.print(t)  // 不应该 panic
  let passed = true

  { name: "PerformanceMetrics::print 不 panic", passed, message: if passed { "ok" } else { "print panic 了" }, duration: 0 }
}

// ============ run_benchmark 集成测试 ============

fn test_run_benchmark_basic() -> TestResult {
  let mut counter = 0
  let r = run_benchmark("计数测试", fn() { counter = counter + 1 }, 5)

  let passed = r.name == "计数测试" &&
    r.iterations == 5 &&
    r.total_time_ms > 0.0 &&
    r.min_time_ms > 0.0 &&
    r.max_time_ms >= r.min_time_ms

  { name: "run_benchmark::基本执行", passed, message: if passed { "ok" } else { "结果不正确" }, duration: 0 }
}

fn test_run_benchmark_min_max() -> TestResult {
  // 🟡 Fix #5 验证：min/max 不依赖魔法数字
  let r = run_benchmark("minmax 测试", fn() { sleep_ms(1) }, 10)

  let passed = r.min_time_ms <= r.avg_time_ms &&
    r.max_time_ms >= r.avg_time_ms

  { name: "run_benchmark::min <= avg <= max（Fix #5）", passed, message: if passed { "ok" } else { "min/max 关系不对" }, duration: 0 }
}

fn test_run_benchmark_zero_iterations() -> TestResult {
  // 边界情况：0 次迭代
  let r = run_benchmark("空测试", fn() {}, 0)

  let passed = r.iterations == 0 &&
    r.avg_time_ms == 0.0

  { name: "run_benchmark::0 次迭代不 panic", passed, message: if passed { "ok" } else { "0 次迭代 panic 了" }, duration: 0 }
}

// ============ 测试套件注册 ============

fn benchmark_test_suite() -> TestSuite {
  TestSuite::{
    name: "Benchmark",
    tests: [
      test_benchmark_result_new,
      test_benchmark_result_compare_pass,
      test_benchmark_result_compare_fail,
      test_benchmark_result_print,
      test_benchmark_target_default,
      test_metrics_collector_new,
      test_metrics_collector_average_empty,
      test_metrics_collector_average_single,
      test_metrics_collector_average_multiple,
      test_int_to_f64,
      test_f64_to_int,
      test_now_ms_f64,
      test_performance_metrics_print,
      test_run_benchmark_basic,
      test_run_benchmark_min_max,
      test_run_benchmark_zero_iterations,
    ],
    setup: None,
    teardown: None,
  }
}
