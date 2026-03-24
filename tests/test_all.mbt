// XiaoClaw 测试

fn test_config() -> Unit {
  let config = Config::load()
  
  assert(config.name == "XiaoClaw")
  assert(config.version == "0.1.0")
  
  println("✅ Config test passed")
}

fn test_context() -> Unit {
  let ctx = Context::new(10)
  
  assert(ctx.messages.length() == 0)
  assert(ctx.max_length == 10)
  
  let ctx2 = ctx.append("user", "Hello")
  assert(ctx2.messages.length() == 1)
  
  println("✅ Context test passed")
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
    handler: || "test",
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

fn run_all_tests() -> Unit {
  println("Running XiaoClaw tests...\n")
  
  test_config()
  test_context()
  test_memory()
  test_scheduler()
  test_cron_parse()
  
  println("\n✅ All tests passed!")
}

fn main {
  run_all_tests()
}