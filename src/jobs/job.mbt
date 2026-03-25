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
}

// Job 优先级
enum JobPriority {
  Low
  Normal
  High
  Critical
}

// Job Verify 条件（来自 GSD 的 <verify> 设计）
enum JobVerifyType {
  OutputContains(String)       // 输出包含指定字符串
  OutputEquals(String)         // 输出完全匹配
  OutputMatches(String)        // 输出匹配正则（简化版：前缀匹配）
  CommandSucceeds(String)      // 执行命令成功（exit code 0）
  CommandOutput(String, String) // 执行命令，输出包含期望值
  Custom(() -> Bool)           // 自定义验证函数
  NoVerify                     // 不验证（默认通过）
}

struct JobVerifyCondition {
  description: String          // 验证描述（人类可读）
  verify_type: JobVerifyType
  required: Bool               // false = 警告但不失败
}

fn JobVerifyCondition::new(desc: String, verify_type: JobVerifyType) -> JobVerifyCondition {
  JobVerifyCondition::{
    description: desc,
    verify_type: verify_type,
    required: true,
  }
}

fn JobVerifyCondition::optional(desc: String, verify_type: JobVerifyType) -> JobVerifyCondition {
  JobVerifyCondition::{
    description: desc,
    verify_type: verify_type,
    required: false,
  }
}

// 验证结果
struct JobVerifyResult {
  condition: JobVerifyCondition
  passed: Bool
  actual_output: String?
  error: String?
}

// Job 定义
struct Job {
  id: String
  name: String
  description: String
  status: JobStatus
  priority: JobPriority

  // 执行信息
  handler: () -> Result[String]
  max_retries: Int
  retry_count: Int

  // ✅ Verify 条件（GSD 风格）
  verify_conditions: Array[JobVerifyCondition]
  verify_results: Array[JobVerifyResult]
  verify_passed: Bool?

  // 时间信息
  created_at: Int
  started_at: Int?
  completed_at: Int?

  // 结果
  result: String?
  error: String?

  // 元数据
  tags: Array[String]
  metadata: Map[String, String]
}

// Job 创建器
struct JobBuilder {
  id: String
  name: String
  description: String
  priority: JobPriority
  max_retries: Int
  tags: Array[String]
  metadata: Map[String, String]
  verify_conditions: Array[JobVerifyCondition]  // ✅ 新增
}

fn JobBuilder::new(id: String, name: String) -> JobBuilder {
  JobBuilder::{
    id: id,
    name: name,
    description: "",
    priority: Normal,
    max_retries: 3,
    tags: [],
    metadata: Map::new(),
    verify_conditions: [],  // ✅ 新增
  }
}

fn JobBuilder::with_description(self: JobBuilder, desc: String) -> JobBuilder {
  JobBuilder::{
    ..self,
    description: desc,
  }
}

fn JobBuilder::with_priority(self: JobBuilder, priority: JobPriority) -> JobBuilder {
  JobBuilder::{
    ..self,
    priority: priority,
  }
}

fn JobBuilder::with_retries(self: JobBuilder, retries: Int) -> JobBuilder {
  JobBuilder::{
    ..self,
    max_retries: retries,
  }
}

fn JobBuilder::with_tag(self: JobBuilder, tag: String) -> JobBuilder {
  let mut tags = self.tags.clone()
  tags.push(tag)
  JobBuilder::{
    ..self,
    tags: tags,
  }
}

// ✅ 新增：Verify 条件 builder 方法

// 验证输出包含指定字符串
fn JobBuilder::verify_output_contains(self: JobBuilder, desc: String, expected: String) -> JobBuilder {
  let mut conditions = self.verify_conditions.clone()
  conditions.push(JobVerifyCondition::new(desc, OutputContains(expected)))
  JobBuilder::{ ..self, verify_conditions: conditions }
}

// 验证输出完全匹配
fn JobBuilder::verify_output_equals(self: JobBuilder, desc: String, expected: String) -> JobBuilder {
  let mut conditions = self.verify_conditions.clone()
  conditions.push(JobVerifyCondition::new(desc, OutputEquals(expected)))
  JobBuilder::{ ..self, verify_conditions: conditions }
}

// 验证命令执行成功
fn JobBuilder::verify_command(self: JobBuilder, desc: String, command: String) -> JobBuilder {
  let mut conditions = self.verify_conditions.clone()
  conditions.push(JobVerifyCondition::new(desc, CommandSucceeds(command)))
  JobBuilder::{ ..self, verify_conditions: conditions }
}

// 验证命令输出包含期望值
fn JobBuilder::verify_command_output(self: JobBuilder, desc: String, command: String, expected: String) -> JobBuilder {
  let mut conditions = self.verify_conditions.clone()
  conditions.push(JobVerifyCondition::new(desc, CommandOutput(command, expected)))
  JobBuilder::{ ..self, verify_conditions: conditions }
}

// 自定义验证函数
fn JobBuilder::verify_custom(self: JobBuilder, desc: String, checker: () -> Bool) -> JobBuilder {
  let mut conditions = self.verify_conditions.clone()
  conditions.push(JobVerifyCondition::new(desc, Custom(checker)))
  JobBuilder::{ ..self, verify_conditions: conditions }
}

// 可选验证（失败只警告，不影响 Job 状态）
fn JobBuilder::verify_optional(self: JobBuilder, desc: String, verify_type: JobVerifyType) -> JobBuilder {
  let mut conditions = self.verify_conditions.clone()
  conditions.push(JobVerifyCondition::optional(desc, verify_type))
  JobBuilder::{ ..self, verify_conditions: conditions }
}

fn JobBuilder::build(self: JobBuilder, handler: () -> Result[String]) -> Job {
  Job::{
    id: self.id,
    name: self.name,
    description: self.description,
    status: Pending,
    priority: self.priority,
    handler: handler,
    max_retries: self.max_retries,
    retry_count: 0,
    verify_conditions: self.verify_conditions,  // ✅ 新增
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
  job_id: String
  status: JobStatus
  result: String?
  error: String?
  duration_ms: Int
  retry_count: Int
  verify_results: Array[JobVerifyResult]  // ✅ 新增
  verify_passed: Bool?                    // ✅ 新增
}

// Job 队列
struct JobQueue {
  jobs: Array[Job]
  running: Bool
  max_concurrent: Int
  current_running: Int
}

fn JobQueue::new(max_concurrent: Int) -> JobQueue {
  JobQueue::{
    jobs: [],
    running: false,
    max_concurrent: max_concurrent,
    current_running: 0,
  }
}

fn JobQueue::enqueue(self: JobQueue, job: Job) -> Unit {
  self.jobs.push(job)
  log_info("Job enqueued: \(job.name) (priority: \(priority_to_string(job.priority)))")
}

fn JobQueue::start(self: JobQueue) -> Unit {
  self.running = true
  log_info("Job queue started")
  
  // 启动处理循环
  spawn(|| self.process_loop())
}

fn JobQueue::stop(self: JobQueue) -> Unit {
  self.running = false
  log_info("Job queue stopped")
}

fn JobQueue::process_loop(self: JobQueue) -> Unit {
  loop {
    if !self.running {
      break
    }
    
    // 检查是否可以运行新 Job
    if self.current_running < self.max_concurrent && self.jobs.length() > 0 {
      // 按优先级排序
      self.sort_by_priority()
      
      // 获取第一个 Job
      let job = self.jobs.remove(0)
      
      // 执行 Job
      self.execute_job(job)
    }
    
    // 等待 100ms
    sleep(100)
  }
}

fn JobQueue::execute_job(self: JobQueue, job: Job) -> Unit {
  self.current_running = self.current_running + 1

  let start_time = now_ms()

  log_info("Job started: \(job.name)")

  // 更新状态
  job.status = Running
  job.started_at = Some(now())

  // 执行 Job handler
  let result = self.run_with_retry(job)

  let duration = now_ms() - start_time

  // 记录执行结果
  match result {
    Ok(output) => {
      job.result = Some(output)

      // ✅ 执行 Verify 条件
      if job.verify_conditions.length() > 0 {
        let verify_passed = self.run_verify(job, output)
        job.verify_passed = Some(verify_passed)

        if verify_passed {
          job.status = Completed
          log_info("Job completed ✅ (verify passed): \(job.name) (\(duration)ms)")
        } else {
          // 必要验证失败 → Job 失败
          let required_failed = job.verify_results.filter(|r| !r.passed && r.condition.required)
          if required_failed.length() > 0 {
            job.status = Failed
            job.error = Some("Verify failed: \(required_failed.map(|r| r.condition.description).join(", "))")
            log_error("Job failed ❌ (verify failed): \(job.name)")
          } else {
            // 只有可选验证失败 → 仍然完成，但有警告
            job.status = Completed
            log_warn("Job completed ⚠️ (optional verify failed): \(job.name) (\(duration)ms)")
          }
        }
      } else {
        // 无 verify 条件，直接完成
        job.status = Completed
        job.verify_passed = Some(true)
        log_info("Job completed: \(job.name) (\(duration)ms)")
      }
    }
    Err(e) => {
      job.status = Failed
      job.error = Some(error_to_string(e))
      job.verify_passed = Some(false)
      log_error("Job failed: \(job.name) - \(error_to_string(e))")
    }
  }

  job.completed_at = Some(now())
  self.current_running = self.current_running - 1
}

// ✅ 执行所有 Verify 条件
fn JobQueue::run_verify(self: JobQueue, job: Job, output: String) -> Bool {
  log_info("Running \(job.verify_conditions.length()) verify condition(s) for: \(job.name)")

  let mut all_required_passed = true

  for condition in job.verify_conditions {
    let result = self.run_single_verify(condition, output)

    if !result.passed {
      if condition.required {
        all_required_passed = false
        log_error("  ❌ FAIL [\(condition.description)]: \(result.error.unwrap_or("unknown error"))")
      } else {
        log_warn("  ⚠️  WARN [\(condition.description)]: \(result.error.unwrap_or("optional check failed"))")
      }
    } else {
      log_info("  ✅ PASS [\(condition.description)]")
    }

    job.verify_results.push(result)
  }

  all_required_passed
}

// 执行单个 Verify 条件
fn JobQueue::run_single_verify(
  self: JobQueue,
  condition: JobVerifyCondition,
  job_output: String
) -> JobVerifyResult {
  let (passed, actual, error) = match condition.verify_type {
    OutputContains(expected) => {
      let ok = job_output.contains(expected)
      (ok, Some(job_output), if ok { None } else { Some("Expected output to contain: '\(expected)'") })
    }

    OutputEquals(expected) => {
      let ok = job_output.trim() == expected.trim()
      (ok, Some(job_output), if ok { None } else { Some("Expected: '\(expected)', got: '\(job_output.trim())'") })
    }

    OutputMatches(prefix) => {
      let ok = job_output.starts_with(prefix)
      (ok, Some(job_output), if ok { None } else { Some("Expected output to start with: '\(prefix)'") })
    }

    CommandSucceeds(cmd) => {
      let exit_code = exec_command_exit_code(cmd)
      let ok = exit_code == 0
      (ok, Some("exit code: \(exit_code)"), if ok { None } else { Some("Command failed with exit code \(exit_code): \(cmd)") })
    }

    CommandOutput(cmd, expected) => {
      let cmd_output = exec_command(cmd)
      let ok = cmd_output.contains(expected)
      (ok, Some(cmd_output), if ok { None } else { Some("Command output did not contain '\(expected)'") })
    }

    Custom(checker) => {
      let ok = checker()
      (ok, None, if ok { None } else { Some("Custom verify condition failed") })
    }

    NoVerify => (true, None, None),
  }

  JobVerifyResult::{
    condition: condition,
    passed: passed,
    actual_output: actual,
    error: error,
  }
}

fn JobQueue::run_with_retry(self: JobQueue, job: Job) -> Result[String] {
  let mut attempts = 0
  
  loop {
    attempts = attempts + 1
    
    match job.handler() {
      Ok(result) => return Ok(result),
      Err(e) => {
        if attempts >= job.max_retries {
          return Err(e)
        }
        
        job.retry_count = attempts
        job.status = Retrying
        
        log_warn("Job retry \(attempts)/\(job.max_retries): \(job.name)")
        
        // 指数退避
        let delay = 100 * (2 ^ (attempts - 1))
        sleep(delay)
      }
    }
  }
}

fn JobQueue::sort_by_priority(self: JobQueue) -> Unit {
  // 按优先级排序 (高优先级在前)
  self.jobs.sort(|a, b| {
    let a_priority = priority_value(a.priority)
    let b_priority = priority_value(b.priority)
    b_priority - a_priority  // 降序
  })
}

fn JobQueue::get_job(self: JobQueue, id: String) -> Job? {
  for job in self.jobs {
    if job.id == id {
      return Some(job)
    }
  }
  None
}

fn JobQueue::cancel_job(self: JobQueue, id: String) -> Bool {
  for i in 0..self.jobs.length() {
    if self.jobs[i].id == id {
      self.jobs[i].status = Cancelled
      log_info("Job cancelled: \(self.jobs[i].name)")
      return true
    }
  }
  false
}

fn JobQueue::get_stats(self: JobQueue) -> JobQueueStats {
  let mut pending = 0
  let mut running = 0
  let mut completed = 0
  let mut failed = 0
  
  for job in self.jobs {
    match job.status {
      Pending => pending = pending + 1
      Running => running = running + 1
      Completed => completed = completed + 1
      Failed => failed = failed + 1
      _ => {}
    }
  }
  
  JobQueueStats::{
    total: self.jobs.length(),
    pending: pending,
    running: running,
    completed: completed,
    failed: failed,
    max_concurrent: self.max_concurrent,
  }
}

// 队列统计
struct JobQueueStats {
  total: Int
  pending: Int
  running: Int
  completed: Int
  failed: Int
  max_concurrent: Int
}

// 辅助函数
fn priority_to_string(priority: JobPriority) -> String {
  match priority {
    Low => "Low"
    Normal => "Normal"
    High => "High"
    Critical => "Critical"
  }
}

fn priority_value(priority: JobPriority) -> Int {
  match priority {
    Low => 1
    Normal => 2
    High => 3
    Critical => 4
  }
}

fn status_to_string(status: JobStatus) -> String {
  match status {
    Pending => "Pending"
    Running => "Running"
    Completed => "Completed"
    Failed => "Failed"
    Cancelled => "Cancelled"
    Retrying => "Retrying"
  }
}

fn now_ms() -> Int {
  now() * 1000
}
