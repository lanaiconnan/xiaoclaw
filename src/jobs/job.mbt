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
  
  // 执行 Job
  let result = self.run_with_retry(job)
  
  let duration = now_ms() - start_time
  
  // 记录结果
  match result {
    Ok(output) => {
      job.status = Completed
      job.result = Some(output)
      log_info("Job completed: \(job.name) (\(duration)ms)")
    }
    Err(e) => {
      job.status = Failed
      job.error = Some(error_to_string(e))
      log_error("Job failed: \(job.name) - \(error_to_string(e))")
    }
  }
  
  job.completed_at = Some(now())
  
  self.current_running = self.current_running - 1
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
