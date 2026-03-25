// XiaoClaw 测试入口
// 整合所有测试套件

fn test_config() -> Unit {
  let config = Config::load()
  assert(config.name == "XiaoClaw")
  assert(config.version == "0.1.0")
  println("✅ Config test passed")
}

fn test_context_basic() -> Unit {
  let ctx = Context::new(10)
  assert(ctx.messages.length() == 0)
  assert(ctx.max_length == 10)
  let ctx2 = ctx.append("user", "Hello")
  assert(ctx2.messages.length() == 1)
  println("✅ Context basic test passed")
}

fn test_memory() -> Unit {
  let store = InMemoryStore::new()
  store.save("key1", "value1")
  assert(store.load("key1") == Some("value1"))
  store.delete("key1")
  assert(store.load("key1") == None)
  println("✅ Memory test passed")
}

fn test_scheduler() -> Unit {
  let scheduler = Scheduler::new()
  let job = CronJob::{
    id: "test",
    name: "Test Job",
    expression: "* * * * *",
    schedule: CronSchedule::parse("* * * * *"),
    handler: fn() { "test" },
    next_run: 0,
    last_run: 0,
    enabled: true,
  }
  scheduler.add_job(job)
  assert(scheduler.jobs.length() == 1)
  println("✅ Scheduler test passed")
}

fn test_cron_parse() -> Unit {
  let schedule = CronSchedule::parse("0 9 * * *")
  match schedule.minute {
    Exact(0) => println("✅ Minute parsed correctly"),
    _ => panic("Minute parse failed"),
  }
  match schedule.hour {
    Exact(9) => println("✅ Hour parsed correctly"),
    _ => panic("Hour parse failed"),
  }
  println("✅ Cron parse test passed")
}

// ============ 新增：使用 TestRunner 运行完整测试套件 ============

fn run_new_test_suites() -> Unit {
  let runner = TestRunner::new()
  runner.verbose = true

  // 注册新测试套件
  runner.add_suite(jobs_test_suite())
  runner.add_suite(context_test_suite())
  runner.add_suite(wave_test_suite())

  // 运行并打印报告
  runner.run_all()
  let report = runner.generate_report()
  println(report)

  // 如果有失败，panic
  let stats = runner.get_stats()
  if stats.failed > 0 {
    panic("\(stats.failed) test(s) failed!")
  }
}

fn run_all_tests() -> Unit {
  println("═══════════════════════════════════════════════════════════")
  println("🥚 XiaoClaw Test Suite")
  println("═══════════════════════════════════════════════════════════")
  println()

  // 原有基础测试
  println("── Legacy Tests ──")
  test_config()
  test_context_basic()
  test_memory()
  test_scheduler()
  test_cron_parse()
  println()

  // 新增：Jobs / Context Manager / Wave Executor 测试
  println("── New Test Suites (Jobs / Context / Wave) ──")
  run_new_test_suites()

  println()
  println("═══════════════════════════════════════════════════════════")
  println("✅ All tests passed!")
  println("═══════════════════════════════════════════════════════════")
}

fn main {
  run_all_tests()
}
