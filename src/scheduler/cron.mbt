// 定时任务调度器

struct Scheduler {
  jobs: Array[CronJob]
  running: Bool
}

struct CronJob {
  id: String
  name: String
  expression: String
  schedule: CronSchedule
  handler: () -> String
  next_run: Int
  last_run: Int
  enabled: Bool
}

struct CronSchedule {
  minute: CronField
  hour: CronField
  day: CronField
  month: CronField
  weekday: CronField
}

type CronField union {
  All,
  Exact(Int),
  Range(Int, Int),
  List(Array[Int]),
}

fn Scheduler::new() -> Scheduler {
  Scheduler::{
    jobs: [],
    running: false,
  }
}

fn Scheduler::start(self: Scheduler) -> Unit {
  self.running = true
  log_info("Scheduler started")
  
  // 启动调度循环
  spawn(|| self.run_loop())
}

fn Scheduler::stop(self: Scheduler) -> Unit {
  self.running = false
  log_info("Scheduler stopped")
}

fn Scheduler::run_loop(self: Scheduler) -> Unit {
  loop {
    if !self.running {
      break
    }
    
    let current_time = now()
    
    // 检查所有任务
    for job in self.jobs {
      if job.enabled && job.next_run <= current_time {
        // 执行任务
        self.execute_job(job)
        
        // 计算下次运行时间
        job.last_run = current_time
        job.next_run = self.calculate_next_run(job.schedule)
      }
    }
    
    // 等待 1 秒
    sleep(1000)
  }
}

fn Scheduler::execute_job(self: Scheduler, job: CronJob) -> Unit {
  log_info("Executing job: \(job.name)")
  
  match job.handler() {
    result => {
      log_info("Job \(job.name) completed: \(result)")
    }
  }
}

fn Scheduler::add_job(self: Scheduler, job: CronJob) -> Unit {
  let job_with_next = CronJob::{
    ..job,
    next_run: self.calculate_next_run(job.schedule),
    last_run: 0,
  }
  
  self.jobs.push(job_with_next)
  log_info("Job added: \(job.name)")
}

fn Scheduler::remove_job(self: Scheduler, id: String) -> Unit {
  self.jobs = self.jobs.filter(|j| j.id != id)
  log_info("Job removed: \(id)")
}

fn Scheduler::list_jobs(self: Scheduler) -> Array[CronJob] {
  self.jobs.clone()
}

// Cron 表达式解析
fn CronSchedule::parse(expr: String) -> CronSchedule {
  let parts = expr.split(" ")
  
  if parts.length() != 5 {
    panic("Invalid cron expression: \(expr)")
  }
  
  CronSchedule::{
    minute: parse_field(parts[0], 0, 59),
    hour: parse_field(parts[1], 0, 23),
    day: parse_field(parts[2], 1, 31),
    month: parse_field(parts[3], 1, 12),
    weekday: parse_field(parts[4], 0, 6),
  }
}

fn parse_field(s: String, min: Int, max: Int) -> CronField {
  if s == "*" {
    All
  } else if s.contains(",") {
    List(s.split(",").map(|x| parse_int(x)))
  } else if s.contains("-") {
    let range = s.split("-")
    Range(parse_int(range[0]), parse_int(range[1]))
  } else {
    Exact(parse_int(s))
  }
}

fn Scheduler::calculate_next_run(self: Scheduler, schedule: CronSchedule) -> Int {
  // 计算下次运行时间
  let now = now()
  let mut next = now + 60  // 至少 1 分钟后
  
  // 简化实现：每分钟检查
  // 完整实现需要考虑所有字段
  next
}

// 预定义任务
fn job_send_summary() -> String {
  "Summary sent"
}

fn job_cleanup() -> String {
  "Cleanup completed"
}

fn job_health_check() -> String {
  "Health check passed"
}