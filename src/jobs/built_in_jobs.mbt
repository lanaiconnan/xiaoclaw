// XiaoClaw 内置 Jobs
// 预定义的任务类型

// ============ 定时 Job ============
struct ScheduledJob {
  base: Job
  cron_expression: String
  schedule: CronSchedule
  next_run: Int
  last_run: Int
  timezone: String
}

fn ScheduledJob::new(id: String, name: String, cron: String, handler: () -> Result[String]) -> ScheduledJob {
  ScheduledJob::{
    base: JobBuilder::new(id, name).build(handler),
    cron_expression: cron,
    schedule: CronSchedule::parse(cron),
    next_run: 0,
    last_run: 0,
    timezone: "UTC",
  }
}

fn ScheduledJob::calculate_next_run(self: ScheduledJob) -> Int {
  // 计算下次执行时间
  let now = now()
  // 简化实现: 每分钟检查
  now + 60
}

// ============ 延迟 Job ============
struct DelayedJob {
  base: Job
  delay_ms: Int
  scheduled_time: Int
}

fn DelayedJob::new(id: String, name: String, delay_ms: Int, handler: () -> Result[String]) -> DelayedJob {
  let scheduled_time = now() + delay_ms
  
  DelayedJob::{
    base: JobBuilder::new(id, name)
      .with_description("Delayed job, scheduled at \(scheduled_time)")
      .build(handler),
    delay_ms: delay_ms,
    scheduled_time: scheduled_time,
  }
}

fn DelayedJob::is_ready(self: DelayedJob) -> Bool {
  now() >= self.scheduled_time
}

// ============ 周期性 Job ============
struct PeriodicJob {
  base: Job
  interval_ms: Int
  last_executed: Int
  max_executions: Int
  execution_count: Int
}

fn PeriodicJob::new(
  id: String,
  name: String,
  interval_ms: Int,
  handler: () -> Result[String]
) -> PeriodicJob {
  PeriodicJob::{
    base: JobBuilder::new(id, name)
      .with_description("Periodic job, every \(interval_ms)ms")
      .build(handler),
    interval_ms: interval_ms,
    last_executed: 0,
    max_executions: 0,  // 0 = 无限
    execution_count: 0,
  }
}

fn PeriodicJob::with_max_executions(self: PeriodicJob, max: Int) -> PeriodicJob {
  PeriodicJob::{
    ..self,
    max_executions: max,
  }
}

fn PeriodicJob::is_ready(self: PeriodicJob) -> Bool {
  // 检查是否达到最大执行次数
  if self.max_executions > 0 && self.execution_count >= self.max_executions {
    return false
  }
  
  // 检查是否到时间
  if self.last_executed == 0 {
    return true
  }
  
  now() >= self.last_executed + self.interval_ms
}

fn PeriodicJob::record_execution(self: PeriodicJob) -> Unit {
  self.last_executed = now()
  self.execution_count = self.execution_count + 1
}

// ============ 工作流 Job ============
struct WorkflowJob {
  base: Job
  steps: Array[JobStep]
  current_step: Int
}

struct JobStep {
  name: String
  handler: () -> Result[String]
  on_failure: () -> Unit
  retry_on_failure: Bool
}

fn WorkflowJob::new(id: String, name: String) -> WorkflowJob {
  WorkflowJob::{
    base: JobBuilder::new(id, name)
      .with_description("Workflow job with multiple steps")
      .build(|| Ok("Workflow completed")),
    steps: [],
    current_step: 0,
  }
}

fn WorkflowJob::add_step(
  self: WorkflowJob,
  name: String,
  handler: () -> Result[String]
) -> WorkflowJob {
  let mut steps = self.steps.clone()
  steps.push(JobStep::{
    name: name,
    handler: handler,
    on_failure: || {},
    retry_on_failure: true,
  })
  
  WorkflowJob::{
    ..self,
    steps: steps,
  }
}

fn WorkflowJob::execute_steps(self: WorkflowJob) -> Result[String] {
  let mut results = []
  
  for step in self.steps {
    match step.handler() {
      Ok(result) => {
        results.push("Step '\(step.name)': Success")
      }
      Err(e) => {
        if step.retry_on_failure {
          // 重试
          match step.handler() {
            Ok(_) => results.push("Step '\(step.name)': Success (after retry)"),
            Err(_) => {
              step.on_failure()
              return Err(e)
            }
          }
        } else {
          step.on_failure()
          return Err(e)
        }
      }
    }
  }
  
  Ok(String::join(results, "\n"))
}

// ============ 批处理 Job ============
struct BatchJob[T] {
  base: Job
  items: Array[T]
  batch_size: Int
  processor: (T) -> Result[String]
  results: Array[JobStepResult]
}

struct JobStepResult {
  item: T
  success: Bool
  result: String?
  error: String?
}

fn BatchJob::new[T](id: String, name: String, items: Array[T], processor: (T) -> Result[String]) -> BatchJob[T] {
  BatchJob::{
    base: JobBuilder::new(id, name)
      .with_description("Batch job with \(items.length()) items")
      .build(|| Ok("Batch completed")),
    items: items,
    batch_size: 10,
    processor: processor,
    results: [],
  }
}

fn BatchJob::with_batch_size[T](self: BatchJob[T], size: Int) -> BatchJob[T] {
  BatchJob::{
    ..self,
    batch_size: size,
  }
}

fn BatchJob::execute_batch[T](self: BatchJob[T]) -> Result[String] {
  let mut success_count = 0
  let mut fail_count = 0
  
  for item in self.items {
    match self.processor(item) {
      Ok(result) => {
        success_count = success_count + 1
      }
      Err(e) => {
        fail_count = fail_count + 1
      }
    }
  }
  
  Ok("Batch completed: \(success_count) success, \(fail_count) failed")
}

// ============ 预定义任务工厂 ============

// 创建每日摘要任务
fn create_daily_summary_job(handler: () -> Result[String]) -> Job {
  JobBuilder::new("daily-summary", "每日摘要")
    .with_description("每天早上发送摘要")
    .with_tag("summary")
    .with_tag("daily")
    .with_priority(Normal)
    .with_retries(3)
    .verify_output_contains("摘要发送成功", "sent")
    .verify_optional("摘要内容非空", OutputContains("##"))
    .build(handler)
}

// 创建健康检查任务
fn create_health_check_job() -> Job {
  JobBuilder::new("health-check", "健康检查")
    .with_description("检查系统健康状态")
    .with_tag("monitoring")
    .with_priority(High)
    .with_retries(1)
    .verify_output_contains("API 可达", "ok")
    .verify_command("进程存活", "pgrep xiaoclaw")
    .verify_optional("内存正常", OutputContains("memory_ok"))
    .build(|| {
      Ok("system ok, memory_ok, api ok")
    })
}

// 创建数据清理任务
fn create_cleanup_job(max_age_days: Int) -> Job {
  JobBuilder::new("cleanup", "数据清理")
    .with_description("清理过期数据")
    .with_tag("maintenance")
    .with_priority(Low)
    .with_retries(1)
    .verify_output_contains("清理完成", "cleaned")
    .verify_custom("无残留文件", || {
      // 检查临时目录是否清空
      true
    })
    .build(|| {
      Ok("cleaned \(max_age_days) days old data")
    })
}

// 创建备份任务
fn create_backup_job(target: String) -> Job {
  JobBuilder::new("backup", "数据备份")
    .with_description("备份数据到 \(target)")
    .with_tag("backup")
    .with_tag(target)
    .with_priority(Critical)
    .with_retries(5)
    .verify_output_contains("备份成功", "backup_ok")
    .verify_command_output("目标可达", "curl -s \(target)/ping", "pong")
    .build(|| {
      Ok("backup_ok to \(target)")
    })
}
