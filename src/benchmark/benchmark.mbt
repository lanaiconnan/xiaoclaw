// XiaoClaw 性能基准测试
// 目标: 验证 WASM 体积 < 5MB, 启动时间 < 100ms

// 基准测试结果
struct BenchmarkResult {
  name: String
  iterations: Int
  total_time_ms: Double
  avg_time_ms: Double
  min_time_ms: Double
  max_time_ms: Double
  memory_bytes: Int
}

// 性能指标
struct PerformanceMetrics {
  startup_time_ms: Double
  wasm_size_kb: Int
  memory_usage_kb: Int
  cold_start_ms: Double
  warm_start_ms: Double
}

// 基准目标
struct BenchmarkTarget {
  name: String
  wasm_size_kb: Int
  startup_time_ms: Double
  memory_usage_kb: Int
}

fn BenchmarkTarget::default() -> BenchmarkTarget {
  BenchmarkTarget::{
    name: "XiaoClaw",
    wasm_size_kb: 5120,  // 5MB
    startup_time_ms: 100,
    memory_usage_kb: 51200,  // 50MB
  }
}

// 创建基准结果
fn BenchmarkResult::new(name: String, iterations: Int) -> BenchmarkResult {
  BenchmarkResult::{
    name: name,
    iterations: iterations,
    total_time_ms: 0.0,
    avg_time_ms: 0.0,
    min_time_ms: 0.0,
    max_time_ms: 0.0,
    memory_bytes: 0,
  }
}

// 运行基准测试
fn run_benchmark(name: String, f: () -> Unit, iterations: Int) -> BenchmarkResult {
  let mut total = 0.0
  let mut min_val = 999999999.0
  let mut max_val = 0.0
  
  // 预热
  f()
  f()
  f()
  
  // 测量
  for i in 0..iterations {
    let start = now_ms()
    f()
    let elapsed = now_ms() - start
    
    total = total + elapsed
    if elapsed < min_val { min_val = elapsed }
    if elapsed > max_val { max_val = elapsed }
  }
  
  let avg = total / iterations
  
  BenchmarkResult::{
    name: name,
    iterations: iterations,
    total_time_ms: total,
    avg_time_ms: avg,
    min_time_ms: min_val,
    max_time_ms: max_val,
    memory_bytes: 0,
  }
}

// 比较结果
fn BenchmarkResult::compare(self: BenchmarkResult, target: BenchmarkTarget) -> Bool {
  self.avg_time_ms < target.startup_time_ms
}

// 打印结果
fn BenchmarkResult::print(self: BenchmarkResult) -> Unit {
  println("")
  println("📊 Benchmark: \(self.name)")
  println("────────────────────────────────────────────────────────────")
  println("  Iterations:  \(self.iterations)")
  println("  Total time:  \(self.total_time_ms)ms")
  println("  Average:      \(self.avg_time_ms)ms")
  println("  Min:          \(self.min_time_ms)ms")
  println("  Max:          \(self.max_time_ms)ms")
}

// 性能指标收集器
struct MetricsCollector {
  samples: Array[PerformanceMetrics]
}

fn MetricsCollector::new() -> MetricsCollector {
  MetricsCollector::{ samples: [] }
}

fn MetricsCollector::add(self: MetricsCollector, metrics: PerformanceMetrics) -> Unit {
  self.samples.push(metrics)
}

fn MetricsCollector::average(self: MetricsCollector) -> PerformanceMetrics {
  if self.samples.length() == 0 {
    return PerformanceMetrics::{
      startup_time_ms: 0.0,
      wasm_size_kb: 0,
      memory_usage_kb: 0,
      cold_start_ms: 0.0,
      warm_start_ms: 0.0,
    }
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
  
  PerformanceMetrics::{
    startup_time_ms: total_startup / len,
    wasm_size_kb: total_size / len,
    memory_usage_kb: total_memory / len,
    cold_start_ms: total_cold / len,
    warm_start_ms: total_warm / len,
  }
}

// 打印性能报告
fn PerformanceMetrics::print(self: PerformanceMetrics, target: BenchmarkTarget) -> Unit {
  println("")
  println("═══════════════════════════════════════════════════════════")
  println("🚀 XiaoClaw 性能报告")
  println("═══════════════════════════════════════════════════════════")
  println("")
  
  // WASM 体积
  let size_pass = self.wasm_size_kb < target.wasm_size_kb
  let size_icon = if size_pass { "✅" } else { "❌" }
  println("  📦 WASM 体积: \(self.wasm_size_kb)KB / \(target.wasm_size_kb)KB \(size_icon)")
  
  // 启动时间
  let startup_pass = self.startup_time_ms < target.startup_time_ms
  let startup_icon = if startup_pass { "✅" } else { "❌" }
  println("  ⚡ 启动时间: \(self.startup_time_ms)ms / \(target.startup_time_ms)ms \(startup_icon)")
  
  // 内存使用
  let mem_pass = self.memory_usage_kb < target.memory_usage_kb
  let mem_icon = if mem_pass { "✅" } else { "❌" }
  println("  💾 内存占用: \(self.memory_usage_kb)KB / \(target.memory_usage_kb)KB \(mem_icon)")
  
  // 冷启动
  let cold_pass = self.cold_start_ms < 100.0
  let cold_icon = if cold_pass { "✅" } else { "❌" }
  println("  ❄️ 冷启动: \(self.cold_start_ms)ms \(cold_icon)")
  
  // 热启动
  let warm_pass = self.warm_start_ms < 10.0
  let warm_icon = if warm_pass { "✅" } else { "❌" }
  println("  🔥 热启动: \(self.warm_start_ms)ms \(warm_icon)")
  
  println("")
  println("────────────────────────────────────────────────────────────")
  
  let all_pass = size_pass && startup_pass && mem_pass && cold_pass && warm_pass
  
  if all_pass {
    println("🎉 所有指标达标！")
  } else {
    println("⚠️ 部分指标未达标，需要优化")
  }
  
  println("═══════════════════════════════════════════════════════════")
}

// 辅助函数
fn now_ms() -> Double {
  (now() * 1000).to_double()
}

fn Double::to_double(self: Int) -> Double {
  self as Double
}
