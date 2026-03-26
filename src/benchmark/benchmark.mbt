// XiaoClaw 性能基准测试
// 目标: 验证 WASM 体积 < 5MB, 启动时间 < 100ms

struct BenchmarkResult {
  name          : String
  iterations    : Int
  total_time_ms : Double
  avg_time_ms   : Double
  min_time_ms   : Double
  max_time_ms   : Double
  memory_bytes  : Int
}

struct PerformanceMetrics {
  startup_time_ms : Double
  wasm_size_kb    : Int
  memory_usage_kb : Int
  cold_start_ms   : Double
  warm_start_ms   : Double
}

struct BenchmarkTarget {
  name             : String
  wasm_size_kb     : Int
  startup_time_ms  : Double
  memory_usage_kb  : Int
}

fn BenchmarkTarget::default() -> BenchmarkTarget {
  { name: "XiaoClaw", wasm_size_kb: 5120, startup_time_ms: 100.0, memory_usage_kb: 51200 }
}

fn BenchmarkResult::new(name : String, iterations : Int) -> BenchmarkResult {
  { name, iterations, total_time_ms: 0.0, avg_time_ms: 0.0, min_time_ms: 0.0, max_time_ms: 0.0, memory_bytes: 0 }
}

// 运行基准测试
fn run_benchmark(name : String, f : () -> Unit, iterations : Int) -> BenchmarkResult {
  // 预热
  f(); f(); f()

  let mut total = 0.0
  // 🟡 Fix #5: 用 Option 代替魔法数字
  let mut min_val : Option[Double] = None
  let mut max_val : Option[Double] = None

  for _ in 0..iterations {
    let start = now_ms_f64()
    f()
    let elapsed = now_ms_f64() - start

    // 🟡 Fix #2: 保持 Double 类型一致
    total = total + elapsed

    match min_val {
      None    => { min_val = Some(elapsed) }
      Some(m) => { if elapsed < m { min_val = Some(elapsed) } }
    }
    match max_val {
      None    => { max_val = Some(elapsed) }
      Some(m) => { if elapsed > m { max_val = Some(elapsed) } }
    }
  }

  let avg = total / int_to_f64(iterations)

  BenchmarkResult::{
    name,
    iterations,
    total_time_ms: total,
    avg_time_ms: avg,
    min_time_ms: min_val.unwrap_or(0.0),
    max_time_ms: max_val.unwrap_or(0.0),
    memory_bytes: 0,
    // 🟢 Fix #7: 明确标注内存测量不可用
  }
}

fn BenchmarkResult::compare(self : BenchmarkResult, target : BenchmarkTarget) -> Bool {
  // 🟡 Fix #6: 用 Double 比较函数
  self.avg_time_ms < target.startup_time_ms
}

fn BenchmarkResult::print(self : BenchmarkResult) -> Unit {
  let lines : Array[String] = [
    "",
    "📊 Benchmark: \(self.name)",
    "────────────────────────────────────────────────────────────",
    "  Iterations:  \(self.iterations)",
    "  Total time:  \(self.total_time_ms)ms",
    "  Average:     \(self.avg_time_ms)ms",
    "  Min:         \(self.min_time_ms)ms",
    "  Max:         \(self.max_time_ms)ms",
    "  Memory:      N/A (WASM)",
  ]
  for l in lines { println(l) }
}

// 性能指标收集器
struct MetricsCollector {
  mut samples : Array[PerformanceMetrics]
}

fn MetricsCollector::new() -> MetricsCollector {
  { samples: [] }
}

fn MetricsCollector::add(self : MetricsCollector, metrics : PerformanceMetrics) -> Unit {
  self.samples.push(metrics)
}

fn MetricsCollector::average(self : MetricsCollector) -> PerformanceMetrics {
  if self.samples.length() == 0 {
    return { startup_time_ms: 0.0, wasm_size_kb: 0, memory_usage_kb: 0, cold_start_ms: 0.0, warm_start_ms: 0.0 }
  }

  let mut total_startup = 0.0
  let mut total_size = 0
  let mut total_memory = 0
  let mut total_cold = 0.0
  let mut total_warm = 0.0

  for m in self.samples {
    total_startup = total_startup + m.startup_time_ms
    total_size = total_size + m.wasm_size_kb
    total_memory = total_memory + m.memory_usage_kb
    total_cold = total_cold + m.cold_start_ms
    total_warm = total_warm + m.warm_start_ms
  }

  let len = self.samples.length()
  // 🔴 Fix #3: 整数除法改浮点除法
  let avg_size = int_to_f64(total_size) / int_to_f64(len)
  let avg_memory = int_to_f64(total_memory) / int_to_f64(len)

  {
    startup_time_ms: total_startup / int_to_f64(len),
    wasm_size_kb: f64_to_int(avg_size),
    memory_usage_kb: f64_to_int(avg_memory),
    cold_start_ms: total_cold / int_to_f64(len),
    warm_start_ms: total_warm / int_to_f64(len),
  }
}

fn PerformanceMetrics::print(self : PerformanceMetrics, target : BenchmarkTarget) -> Unit {
  let size_pass = self.wasm_size_kb < target.wasm_size_kb
  let startup_pass = self.startup_time_ms < target.startup_time_ms
  let mem_pass = self.memory_usage_kb < target.memory_usage_kb
  let cold_pass = self.cold_start_ms < 100.0
  let warm_pass = self.warm_start_ms < 10.0

  let lines : Array[String] = [
    "",
    "═══════════════════════════════════════════════════════════",
    "🚀 XiaoClaw 性能报告",
    "═══════════════════════════════════════════════════════════",
    "",
    "  📦 WASM 体积: \(self.wasm_size_kb)KB / \(target.wasm_size_kb)KB \(if size_pass { "✅" } else { "❌" })",
    "  ⚡ 启动时间: \(self.startup_time_ms)ms / \(target.startup_time_ms)ms \(if startup_pass { "✅" } else { "❌" })",
    "  💾 内存占用: \(self.memory_usage_kb)KB / \(target.memory_usage_kb)KB \(if mem_pass { "✅" } else { "❌" })",
    "  ❄️ 冷启动: \(self.cold_start_ms)ms \(if cold_pass { "✅" } else { "❌" })",
    "  🔥 热启动: \(self.warm_start_ms)ms \(if warm_pass { "✅" } else { "❌" })",
    "",
    "────────────────────────────────────────────────────────────",
    if size_pass && startup_pass && mem_pass && cold_pass && warm_pass {
      "🎉 所有指标达标！"
    } else {
      "⚠️ 部分指标未达标，需要优化"
    },
    "═══════════════════════════════════════════════════════════",
  ]
  for l in lines { println(l) }
}

// ============ 辅助函数 ============

// 🔴 Fix #1: 修复 to_double 签名，MoonBit 需要独立函数
fn int_to_f64(n : Int) -> Double {
  @f64.from_int(n)
}

fn f64_to_int(d : Double) -> Int {
  @f64.to_int(d)
}

fn now_ms_f64() -> Double {
  int_to_f64(now()) * 1000.0
}
