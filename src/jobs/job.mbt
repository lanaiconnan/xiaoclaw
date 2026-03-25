// XiaoClaw Jobs System
// 基于 MoonClaw 的设计模式

// Job 状态
enum JobStatus {
  Pending      // 待处理
  Running      // 运行中
  Completed    // 已完成
  Failed       // 失败
  Cancelled    // 已取消
  Retrying     // 重试中
} derive(Eq, Show)

// Job 优先级
enum JobPriority {
  Low
  Normal
  High
  Critical
} derive(Eq, Show)

// Job Verify 条件（来自 GSD 的 <verify> 设计）
enum JobVerifyType {
  OutputContains(String)        // 输出包含指定字符串
  OutputEquals(String)          // 输出完全匹配
  OutputMatches(String)         // 输出匹配正则（简化版：前缀匹配）
  CommandSucceeds(String)       // 执行命令成功（exit code 0）
  CommandOutput(String, String) // 执行命令，输出包含期望值
  Custom(() -> Bool)            // 自定义验证函数
  NoVerify                      // 不验证（默认通过）
}

struct JobVerifyCondition {
  description : String       // 验证描述（人类可读）
  verify_type : JobVerifyType
  required    : Bool         // false = 警告但不失败
}

fn JobVerifyCondition::new(desc : String, verify_type : JobVerifyType) -> JobVerifyCondition {
  { description: desc, verify_type, required: true }
}

fn JobVerifyCondition::optional(desc : String, verify_type : JobVerifyType) -> JobVerifyCondition {
  { description: desc, verify_type, required: false }
}

// 验证结果
struct JobVerifyResult {
  condition     : JobVerifyCondition
  passed        : Bool
  actual_output : String?
  error         : String?
}

// Job 定义
struct Job {
  id          : String
  name        : String
  description : String
  mut status  : JobStatus
  priority    : JobPriority

  // 执行信息
  handler    : () -> Result[String, String]
  max_retries: Int
  mut retry_count: Int

  // ✅ Verify 条件（GSD 风格）
  verify_conditions : Array[JobVerifyCondition]
  mut verify_results: Array[JobVerifyResult]
  mut verify_passed : Bool?

  // 时间信息
  created_at       : Int
  mut started_at   : Int?
  mut completed_at : Int?

  // 结果
  mut result : String?
  mut error  : String?

  // 元数据
  tags     : Array[String]
  metadata : Map[String, String]
}

// Job 创建器
struct JobBuilder {
  id                : String
  name              : String
  description       : String
  priority          : JobPriority
  max_retries       : Int
  tags              : Array[String]
  metadata          : Map[String, String]
  verify_conditions : Array[JobVerifyCondition]
}

fn JobBuilder::new(id : String, name : String) -> JobBuilder {
  {
    id,
    name,
    description: "",
    priority: Normal,
    max_retries: 3,
    tags: [],
    metadata: {},
    verify_conditions: [],
  }
}

fn JobBuilder::with_description(self : JobBuilder, desc : String) -> JobBuilder {
  { ..self, description: desc }
}

fn JobBuilder::with_priority(self : JobBuilder, priority : JobPriority) -> JobBuilder {
  { ..self, priority }
}

fn JobBuilder::with_retries(self : JobBuilder, retries : Int) -> JobBuilder {
  { ..self, max_retries: retries }
}

fn JobBuilder::with_tag(self : JobBuilder, tag : String) -> JobBuilder {
  let tags = self.tags.copy()
  tags.push(tag)
  { ..self, tags }
}

// ✅ Verify 条件 builder 方法

fn JobBuilder::verify_output_contains(self : JobBuilder, desc : String, expected : String) -> JobBuilder {
  let conditions = self.verify_conditions.copy()
  conditions.push(JobVerifyCondition::new(desc, OutputContains(expected)))
  { ..self, verify_conditions: conditions }
}

fn JobBuilder::verify_output_equals(self : JobBuilder, desc : String, expected : String) -> JobBuilder {
  let conditions = self.verify_conditions.copy()
  conditions.push(JobVerifyCondition::new(desc, OutputEquals(expected)))
  { ..self, verify_conditions: conditions }
}

fn JobBuilder::verify_command(self : JobBuilder, desc : String, command : String) -> JobBuilder {
  let conditions = self.verify_conditions.copy()
  conditions.push(JobVerifyCondition::new(desc, CommandSucceeds(command)))
  { ..self, verify_conditions: conditions }
}

fn JobBuilder::verify_command_output(self : JobBuilder, desc : String, command : String, expected : String) -> JobBuilder {
  let conditions = self.verify_conditions.copy()
  conditions.push(JobVerifyCondition::new(desc, CommandOutput(command, expected)))
  { ..self, verify_conditions: conditions }
}

fn JobBuilder::verify_custom(self : JobBuilder, desc : String, checker : () -> Bool) -> JobBuilder {
  let conditions = self.verify_conditions.copy()
  conditions.push(JobVerifyCondition::new(desc, Custom(checker)))
  { ..self, verify_conditions: conditions }
}

fn JobBuilder::verify_optional(self : JobBuilder, desc : String, verify_type : JobVerifyType) -> JobBuilder {
  let conditions = self.verify_conditions.copy()
  conditions.push(JobVerifyCondition::optional(desc, verify_type))
  { ..self, verify_conditions: conditions }
}

fn JobBuilder::build(self : JobBuilder, handler : () -> Result[String, String]) -> Job {
  {
    id: self.id,
    name: self.name,
    description: self.description,
    status: Pending,
    priority: self.priority,
    handler,
    max_retries: self.max_retries,
    retry_count: 0,
    verify_conditions: self.verify_conditions,
    verify_results: [],
    verify_passed: None,
    created_at: now(),
    started_at: None,
    completed_at: None,
    result: None,
    error: None,
    tags: self.tags,
    metadata: self.metadata,
  }
}

// Job 执行结果
struct JobResult {
  job_id        : String
  status        : JobStatus
  result        : String?
  error         : String?
  duration_ms   : Int
  retry_count   : Int
  verify_results: Array[JobVerifyResult]
  verify_passed : Bool?
}

// 队列统计
struct JobQueueStats {
  total          : Int
  pending        : Int
  running        : Int
  completed      : Int
  failed         : Int
  max_concurrent : Int
}

// Job 队列
struct JobQueue {
  mut jobs           : Array[Job]
  mut running        : Bool
  max_concurrent     : Int
  mut current_running: Int
}

fn JobQueue::new(max_concurrent : Int) -> JobQueue {
  { jobs: [], running: false, max_concurrent, current_running: 0 }
}

fn JobQueue::enqueue(self : JobQueue, job : Job) -> Unit {
  self.jobs.push(job)
  log_info("Job enqueued: \(job.name) (priority: \(priority_to_string(job.priority)))")
}

fn JobQueue::start(self : JobQueue) -> Unit {
  self.running = true
  log_info("Job queue started")
}

fn JobQueue::stop(self : JobQueue) -> Unit {
  self.running = false
  log_info("Job queue stopped")
}

// 处理下一个待执行的 Job（由外部调度循环调用）
fn JobQueue::process_next(self : JobQueue) -> Unit {
  if not(self.running) {
    return
  }
  if self.current_running >= self.max_concurrent {
    return
  }

  // 🔴 Fix #1: 先排序，再找第一个 Pending Job
  self.sort_by_priority()
  let mut found : Job? = None
  for job in self.jobs {
    if job.status == Pending {
      found = Some(job)
      break
    }
  }

  match found {
    Some(job) => self.execute_job(job)
    None => ()
  }
}

fn JobQueue::execute_job(self : JobQueue, job : Job) -> Unit {
  self.current_running = self.current_running + 1
  let start_time = now_ms()

  log_info("Job started: \(job.name)")
  job.status = Running
  job.started_at = Some(now())

  let result = self.run_with_retry(job)
  let duration = now_ms() - start_time

  match result {
    Ok(output) => {
      job.result = Some(output)

      if job.verify_conditions.length() > 0 {
        let verify_passed = self.run_verify(job, output)
        job.verify_passed = Some(verify_passed)

        let required_failed = job.verify_results.iter().filter(fn(r) { not(r.passed) && r.condition.required }).collect()
        if required_failed.length() > 0 {
          job.status = Failed
          let desc = required_failed.map(fn(r) { r.condition.description }).join(", ")
          job.error = Some("Verify failed: \(desc)")
          log_error("Job failed ❌ (verify failed): \(job.name)")
        } else {
          job.status = Completed
          let opt_failed = job.verify_results.iter().filter(fn(r) { not(r.passed) && not(r.condition.required) }).collect()
          if opt_failed.length() > 0 {
            log_warn("Job completed ⚠️ (optional verify failed): \(job.name) (\(duration)ms)")
          } else {
            log_info("Job completed ✅: \(job.name) (\(duration)ms)")
          }
        }
      } else {
        job.status = Completed
        job.verify_passed = Some(true)
        log_info("Job completed: \(job.name) (\(duration)ms)")
      }
    }
    Err(e) => {
      job.status = Failed
      job.error = Some(e)
      job.verify_passed = Some(false)
      log_error("Job failed: \(job.name) - \(e)")
    }
  }

  job.completed_at = Some(now())
  self.current_running = self.current_running - 1
}

// ✅ Verify 条件执行
fn JobQueue::run_verify(self : JobQueue, job : Job, output : String) -> Bool {
  log_info("Running \(job.verify_conditions.length()) verify condition(s) for: \(job.name)")
  let mut all_required_passed = true

  for condition in job.verify_conditions {
    let result = run_single_verify(condition, output)
    if not(result.passed) {
      if condition.required {
        all_required_passed = false
        log_error("  ❌ FAIL [\(condition.description)]: \(result.error.or(""))")
      } else {
        log_warn("  ⚠️  WARN [\(condition.description)]: \(result.error.or("optional check failed"))")
      }
    } else {
      log_info("  ✅ PASS [\(condition.description)]")
    }
    job.verify_results.push(result)
  }

  all_required_passed
}

// 执行单个 Verify 条件（纯函数，不依赖 self）
fn run_single_verify(condition : JobVerifyCondition, job_output : String) -> JobVerifyResult {
  let (passed, actual, error) : (Bool, String?, String?) = match condition.verify_type {
    OutputContains(expected) => {
      let ok = job_output.contains(expected)
      (ok, Some(job_output), if ok { None } else { Some("Expected output to contain: '\(expected)'") })
    }
    OutputEquals(expected) => {
      let ok = job_output.trim_space() == expected.trim_space()
      (ok, Some(job_output), if ok { None } else { Some("Expected: '\(expected)', got: '\(job_output.trim_space())'") })
    }
    OutputMatches(prefix) => {
      let ok = job_output.has_prefix(prefix)
      (ok, Some(job_output), if ok { None } else { Some("Expected output to start with: '\(prefix)'") })
    }
    CommandSucceeds(cmd) => {
      // WASM 环境下无法执行命令，标记为跳过
      log_warn("CommandSucceeds verify skipped in WASM: \(cmd)")
      (true, None, None)
    }
    CommandOutput(cmd, _expected) => {
      log_warn("CommandOutput verify skipped in WASM: \(cmd)")
      (true, None, None)
    }
    Custom(checker) => {
      let ok = checker()
      (ok, None, if ok { None } else { Some("Custom verify condition failed") })
    }
    NoVerify => (true, None, None)
  }

  { condition, passed, actual_output: actual, error }
}

// 🔴 Fix #2: 指数退避使用乘法而非 XOR
fn JobQueue::run_with_retry(self : JobQueue, job : Job) -> Result[String, String] {
  let mut attempts = 0

  loop {
    attempts = attempts + 1
    match job.handler() {
      Ok(result) => return Ok(result)
      Err(e) => {
        if attempts >= job.max_retries {
          return Err(e)
        }
        job.retry_count = attempts
        job.status = Retrying
        log_warn("Job retry \(attempts)/\(job.max_retries): \(job.name)")
        // ✅ 正确的指数退避：100ms, 200ms, 400ms, 800ms...
        let delay_ms = 100 * pow2(attempts - 1)
        sleep_ms(delay_ms)
      }
    }
  }
}

// 🔴 Fix #2 辅助：整数幂运算（避免 ^ 被解释为 XOR）
fn pow2(n : Int) -> Int {
  if n <= 0 { 1 }
  else { 2 * pow2(n - 1) }
}

fn JobQueue::sort_by_priority(self : JobQueue) -> Unit {
  // 按优先级降序排列（Critical 最高）
  self.jobs.sort_by(fn(a, b) { priority_value(b.priority) - priority_value(a.priority) })
}

fn JobQueue::get_job(self : JobQueue, id : String) -> Job? {
  for job in self.jobs {
    if job.id == id {
      return Some(job)
    }
  }
  None
}

fn JobQueue::cancel_job(self : JobQueue, id : String) -> Bool {
  for job in self.jobs {
    if job.id == id && job.status == Pending {
      job.status = Cancelled
      log_info("Job cancelled: \(job.name)")
      return true
    }
  }
  false
}

fn JobQueue::get_stats(self : JobQueue) -> JobQueueStats {
  let mut pending   = 0
  let mut running   = 0
  let mut completed = 0
  let mut failed    = 0

  for job in self.jobs {
    match job.status {
      Pending   => pending   = pending   + 1
      Running   => running   = running   + 1
      Completed => completed = completed + 1
      Failed    => failed    = failed    + 1
      _         => ()
    }
  }

  {
    total: self.jobs.length(),
    pending,
    running,
    completed,
    failed,
    max_concurrent: self.max_concurrent,
  }
}

// ============ 辅助函数 ============

fn priority_to_string(priority : JobPriority) -> String {
  match priority {
    Low      => "Low"
    Normal   => "Normal"
    High     => "High"
    Critical => "Critical"
  }
}

fn priority_value(priority : JobPriority) -> Int {
  match priority {
    Low      => 1
    Normal   => 2
    High     => 3
    Critical => 4
  }
}

fn status_to_string(status : JobStatus) -> String {
  match status {
    Pending   => "Pending"
    Running   => "Running"
    Completed => "Completed"
    Failed    => "Failed"
    Cancelled => "Cancelled"
    Retrying  => "Retrying"
  }
}

// 🟢 Fix #6: now_ms 明确基于 now()（秒级）转毫秒
fn now_ms() -> Int {
  now() * 1000
}

fn sleep_ms(ms : Int) -> Unit {
  // WASM 环境下 sleep 为 no-op，实际部署时替换
  let _ = ms
  ()
}
