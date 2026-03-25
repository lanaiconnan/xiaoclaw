// XiaoClaw 测试框架

// 测试结果
struct TestResult {
  name: String
  passed: Bool
  message: String
  duration: Int  // 毫秒
}

// 测试套件
struct TestSuite {
  name: String
  tests: Array[Test]
  setup: (() -> Unit)?
  teardown: (() -> Unit)?
}

// 测试函数类型
type Test = () -> TestResult

// 测试运行器
struct TestRunner {
  suites: Array[TestSuite]
  results: Array[TestResult]
  verbose: Bool
}

fn TestRunner::new() -> TestRunner {
  TestRunner::{
    suites: [],
    results: [],
    verbose: false,
  }
}

fn TestRunner::add_suite(self: TestRunner, suite: TestSuite) -> Unit {
  self.suites.push(suite)
}

fn TestRunner::run(self: TestRunner) -> TestSummary {
  println("═══════════════════════════════════════════════════════════")
  println("🧪 XiaoClaw Test Runner")
  println("═══════════════════════════════════════════════════════════")
  println("")
  
  let mut total_passed = 0
  let mut total_failed = 0
  let mut total_time = 0
  
  for suite in self.suites {
    println("📦 Suite: \(suite.name)")
    println("────────────────────────────────────────────────────────────")
    
    // 运行 setup
    match suite.setup {
      Some(s) => s(),
      None => {},
    }
    
    for test in suite.tests {
      let start = now_ms()
      let result = test()
      let duration = now_ms() - start
      
      let final_result = TestResult::{
        name: result.name,
        passed: result.passed,
        message: result.message,
        duration: duration,
      }
      
      self.results.push(final_result)
      
      if final_result.passed {
        total_passed = total_passed + 1
        if self.verbose {
          println("  ✅ \(final_result.name) (\(duration)ms)")
        } else {
          println("  ✅ \(final_result.name)")
        }
      } else {
        total_failed = total_failed + 1
        println("  ❌ \(final_result.name)")
        println("     Error: \(final_result.message)")
      }
      
      total_time = total_time + duration
    }
    
    // 运行 teardown
    match suite.teardown {
      Some(t) => t(),
      None => {},
    }
    
    println("")
  }
  
  // 打印摘要
  println("═══════════════════════════════════════════════════════════")
  println("📊 Test Summary")
  println("═══════════════════════════════════════════════════════════")
  println("")
  println("  Total:   \(total_passed + total_failed)")
  println("  Passed:  \(total_passed)")
  println("  Failed:  \(total_failed)")
  println("  Time:    \(total_time)ms")
  println("")
  
  if total_failed == 0 {
    println("✅ All tests passed!")
  } else {
    println("❌ \(total_failed) test(s) failed")
  }
  
  TestSummary::{
    total: total_passed + total_failed,
    passed: total_passed,
    failed: total_failed,
    time_ms: total_time,
  }
}

// 测试摘要
struct TestSummary {
  total: Int
  passed: Int
  failed: Int
  time_ms: Int
}

// 断言函数
fn assert_true(condition: Bool, message: String) -> Unit {
  if !condition {
    panic("Assertion failed: \(message)")
  }
}

fn assert_false(condition: Bool, message: String) -> Unit {
  if condition {
    panic("Assertion failed: \(message)")
  }
}

fn assert_eq[T](expected: T, actual: T, message: String) -> Unit where T: Eq {
  if expected != actual {
    panic("Assertion failed: expected \(expected), got \(actual). \(message)")
  }
}

fn assert_ne[T](expected: T, actual: T, message: String) -> Unit where T: Eq {
  if expected == actual {
    panic("Assertion failed: values should not be equal. \(message)")
  }
}

fn assert_contains(haystack: String, needle: String, message: String) -> Unit {
  if !haystack.contains(needle) {
    panic("Assertion failed: '\(haystack)' does not contain '\(needle)'. \(message)")
  }
}

fn assert_starts_with(s: String, prefix: String, message: String) -> Unit {
  if !s.starts_with(prefix) {
    panic("Assertion failed: '\(s)' does not start with '\(prefix)'. \(message)")
  }
}

fn assert_len[T](arr: Array[T], expected_len: Int, message: String) -> Unit {
  if arr.length() != expected_len {
    panic("Assertion failed: array length is \(arr.length()), expected \(expected_len). \(message)")
  }
}

// 测试辅助函数
fn test_pass(name: String) -> TestResult {
  TestResult::{
    name: name,
    passed: true,
    message: "",
    duration: 0,
  }
}

fn test_fail(name: String, message: String) -> TestResult {
  TestResult::{
    name: name,
    passed: false,
    message: message,
    duration: 0,
  }
}

// 时间函数 (毫秒)
fn now_ms() -> Int {
  now() * 1000
}
