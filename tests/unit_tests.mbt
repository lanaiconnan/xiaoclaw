// XiaoClaw 单元测试

// 导入测试框架
// use test_framework::*;

// 配置测试
fn test_config_load() -> TestResult {
  let config = Config::load()
  
  // 验证默认值
  assert_eq("XiaoClaw", config.name, "name should be XiaoClaw")
  assert_eq("0.1.0", config.version, "version should be 0.1.0")
  
  test_pass("test_config_load")
}

fn test_config_default() -> TestResult {
  let config = Config::load()
  
  // 验证通道配置
  assert_false(config.channels.whatsapp.enabled, "WhatsApp should be disabled by default")
  
  test_pass("test_config_default")
}

// Context 测试
fn test_context_new() -> TestResult {
  let ctx = Context::new(10)
  
  assert_eq(0, ctx.messages.length(), "new context should have no messages")
  assert_eq(10, ctx.max_length, "max_length should be 10")
  
  test_pass("test_context_new")
}

fn test_context_append() -> TestResult {
  let ctx = Context::new(10)
  
  let ctx2 = ctx.append("user", "Hello")
  assert_eq(1, ctx2.messages.length(), "should have 1 message")
  
  let ctx3 = ctx2.append("assistant", "Hi there!")
  assert_eq(2, ctx3.messages.length(), "should have 2 messages")
  
  test_pass("test_context_append")
}

fn test_context_limit() -> TestResult {
  let ctx = Context::new(3)
  
  let ctx2 = ctx.append("user", "msg1").append("user", "msg2").append("user", "msg3")
  assert_eq(3, ctx2.messages.length(), "should have 3 messages")
  
  // 超过限制时应该删除最早的消息
  let ctx3 = ctx2.append("user", "msg4")
  assert_eq(3, ctx3.messages.length(), "should still have 3 messages")
  
  test_pass("test_context_limit")
}

// Memory 测试
fn test_memory_save_load() -> TestResult {
  let store = InMemoryStore::new()
  
  store.save("key1", "value1")
  
  match store.load("key1") {
    Some(v) => assert_eq("value1", v, "loaded value should match"),
    None => return test_fail("test_memory_save_load", "key not found"),
  }
  
  test_pass("test_memory_save_load")
}

fn test_memory_delete() -> TestResult {
  let store = InMemoryStore::new()
  
  store.save("key1", "value1")
  store.delete("key1")
  
  match store.load("key1") {
    Some(_) => return test_fail("test_memory_delete", "key should be deleted"),
    None => {},
  }
  
  test_pass("test_memory_delete")
}

fn test_memory_list() -> TestResult {
  let store = InMemoryStore::new()
  
  store.save("user:1", "data1")
  store.save("user:2", "data2")
  store.save("other:1", "data3")
  
  let user_keys = store.list("user:")
  assert_eq(2, user_keys.length(), "should have 2 user keys")
  
  test_pass("test_memory_list")
}

// Scheduler 测试
fn test_scheduler_new() -> TestResult {
  let scheduler = Scheduler::new()
  
  assert_eq(0, scheduler.jobs.length(), "new scheduler should have no jobs")
  assert_false(scheduler.running, "scheduler should not be running")
  
  test_pass("test_scheduler_new")
}

fn test_scheduler_add_job() -> TestResult {
  let scheduler = Scheduler::new()
  
  let job = CronJob::{
    id: "test-1",
    name: "Test Job",
    expression: "* * * * *",
    schedule: CronSchedule::parse("* * * * *"),
    handler: || "test",
    next_run: 0,
    last_run: 0,
    enabled: true,
  }
  
  scheduler.add_job(job)
  assert_eq(1, scheduler.jobs.length(), "should have 1 job")
  
  test_pass("test_scheduler_add_job")
}

fn test_scheduler_remove_job() -> TestResult {
  let scheduler = Scheduler::new()
  
  let job = CronJob::{
    id: "test-1",
    name: "Test Job",
    expression: "* * * * *",
    schedule: CronSchedule::parse("* * * * *"),
    handler: || "test",
    next_run: 0,
    last_run: 0,
    enabled: true,
  }
  
  scheduler.add_job(job)
  scheduler.remove_job("test-1")
  
  assert_eq(0, scheduler.jobs.length(), "should have no jobs")
  
  test_pass("test_scheduler_remove_job")
}

// Cron 解析测试
fn test_cron_parse_all() -> TestResult {
  let schedule = CronSchedule::parse("* * * * *")
  
  match schedule.minute {
    All => {},
    _ => return test_fail("test_cron_parse_all", "minute should be All"),
  }
  
  match schedule.hour {
    All => {},
    _ => return test_fail("test_cron_parse_all", "hour should be All"),
  }
  
  test_pass("test_cron_parse_all")
}

fn test_cron_parse_exact() -> TestResult {
  let schedule = CronSchedule::parse("0 9 * * *")
  
  match schedule.minute {
    Exact(0) => {},
    _ => return test_fail("test_cron_parse_exact", "minute should be Exact(0)"),
  }
  
  match schedule.hour {
    Exact(9) => {},
    _ => return test_fail("test_cron_parse_exact", "hour should be Exact(9)"),
  }
  
  test_pass("test_cron_parse_exact")
}

fn test_cron_parse_range() -> TestResult {
  let schedule = CronSchedule::parse("0 9-17 * * 1-5")
  
  match schedule.hour {
    Range(9, 17) => {},
    _ => return test_fail("test_cron_parse_range", "hour should be Range(9, 17)"),
  }
  
  match schedule.weekday {
    Range(1, 5) => {},
    _ => return test_fail("test_cron_parse_range", "weekday should be Range(1, 5)"),
  }
  
  test_pass("test_cron_parse_range")
}

// Error 测试
fn test_error_codes() -> TestResult {
  let e1 = ConfigNotFound("test")
  assert_eq("E001", error_code(e1), "ConfigNotFound should be E001")
  
  let e2 = NetworkError("timeout")
  assert_eq("E101", error_code(e2), "NetworkError should be E101")
  
  let e3 = AuthError("invalid token")
  assert_eq("E202", error_code(e3), "AuthError should be E202")
  
  test_pass("test_error_codes")
}

fn test_error_retryable() -> TestResult {
  assert_true(is_retryable(NetworkError("test")), "NetworkError should be retryable")
  assert_true(is_retryable(Timeout(1000)), "Timeout should be retryable")
  assert_true(is_retryable(RateLimitError(60)), "RateLimitError should be retryable")
  assert_false(is_retryable(ConfigNotFound("test")), "ConfigNotFound should not be retryable")
  
  test_pass("test_error_retryable")
}

fn test_result_methods() -> TestResult {
  let r1: Result[Int] = Ok(42)
  assert_true(r1.is_ok(), "Ok should be ok")
  assert_false(r1.is_err(), "Ok should not be err")
  assert_eq(42, r1.unwrap(), "unwrap should return 42")
  
  let r2: Result[Int] = Err(NetworkError("test"))
  assert_false(r2.is_ok(), "Err should not be ok")
  assert_true(r2.is_err(), "Err should be err")
  assert_eq(0, r2.unwrap_or(0), "unwrap_or should return default")
  
  test_pass("test_result_methods")
}

// Plugin 测试
fn test_plugin_meta() -> TestResult {
  let plugin = HealthCheckPlugin::new()
  let meta = plugin.meta()
  
  assert_eq("health-check", meta.name, "plugin name should be health-check")
  assert_eq("1.0.0", meta.version, "plugin version should be 1.0.0")
  
  test_pass("test_plugin_meta")
}

fn test_plugin_manager() -> TestResult {
  let ctx = PluginContext::default()
  let manager = PluginManager::new(ctx, "./plugins")
  
  let plugin = HealthCheckPlugin::new()
  
  match manager.register(plugin) {
    Ok(_) => {},
    Err(e) => return test_fail("test_plugin_manager", "register failed"),
  }
  
  let plugins = manager.list()
  assert_eq(1, plugins.length(), "should have 1 plugin")
  
  test_pass("test_plugin_manager")
}

// 运行所有测试
fn run_all_tests() -> TestSummary {
  let runner = TestRunner::new()
  
  // 配置测试套件
  let config_suite = TestSuite::{
    name: "Config",
    tests: [
      test_config_load,
      test_config_default,
    ],
    setup: None,
    teardown: None,
  }
  
  // Context 测试套件
  let context_suite = TestSuite::{
    name: "Context",
    tests: [
      test_context_new,
      test_context_append,
      test_context_limit,
    ],
    setup: None,
    teardown: None,
  }
  
  // Memory 测试套件
  let memory_suite = TestSuite::{
    name: "Memory",
    tests: [
      test_memory_save_load,
      test_memory_delete,
      test_memory_list,
    ],
    setup: None,
    teardown: None,
  }
  
  // Scheduler 测试套件
  let scheduler_suite = TestSuite::{
    name: "Scheduler",
    tests: [
      test_scheduler_new,
      test_scheduler_add_job,
      test_scheduler_remove_job,
    ],
    setup: None,
    teardown: None,
  }
  
  // Cron 测试套件
  let cron_suite = TestSuite::{
    name: "Cron",
    tests: [
      test_cron_parse_all,
      test_cron_parse_exact,
      test_cron_parse_range,
    ],
    setup: None,
    teardown: None,
  }
  
  // Error 测试套件
  let error_suite = TestSuite::{
    name: "Error",
    tests: [
      test_error_codes,
      test_error_retryable,
      test_result_methods,
    ],
    setup: None,
    teardown: None,
  }
  
  // Plugin 测试套件
  let plugin_suite = TestSuite::{
    name: "Plugin",
    tests: [
      test_plugin_meta,
      test_plugin_manager,
    ],
    setup: None,
    teardown: None,
  }
  
  runner.add_suite(config_suite)
  runner.add_suite(context_suite)
  runner.add_suite(memory_suite)
  runner.add_suite(scheduler_suite)
  runner.add_suite(cron_suite)
  runner.add_suite(error_suite)
  runner.add_suite(plugin_suite)
  
  runner.run()
}

fn main {
  let summary = run_all_tests()
  
  if summary.failed > 0 {
    exit(1)
  }
}
