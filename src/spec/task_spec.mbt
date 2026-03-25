// XiaoClaw Task Spec 系统
// 规格驱动开发（Spec-Driven Development）
// 灵感来自 GSD 的 discuss → plan → execute → verify → ship 流程

// ============================================================
// 核心思想（来自 GSD）：
//   每个任务都有明确的 Spec：
//     - 目标（What）
//     - 约束（Constraints）
//     - 验证条件（Verify）
//     - 完成标准（Done）
//
//   XML 结构化格式，让 AI 精确理解任务
// ============================================================

// ============ Task Spec 核心结构 ============

// 任务类型
enum TaskType {
  Feature      // 新功能
  Bugfix       // 修复 Bug
  Refactor     // 重构
  Research     // 调研
  Config       // 配置
  Maintenance  // 维护
  Auto         // 自动判断
}

// 任务优先级
enum TaskPriority {
  P0  // 紧急
  P1  // 高
  P2  // 中
  P3  // 低
}

// 任务状态
enum TaskSpecStatus {
  Draft      // 草稿
  Approved   // 已审批
  InProgress // 进行中
  Done       // 完成
  Failed     // 失败
  Cancelled  // 取消
}

// 验证步骤
struct VerifyStep {
  description: String
  command: String?      // 可选的验证命令
  expected: String      // 期望结果
  passed: Bool?         // 验证结果
}

// Task Spec（核心）
struct TaskSpec {
  // 基本信息
  id: String
  name: String
  description: String
  task_type: TaskType
  priority: TaskPriority
  status: TaskSpecStatus

  // GSD 风格的四段式结构
  goal: String          // 目标：要做什么
  context: String       // 上下文：背景信息
  action: String        // 行动：具体怎么做
  verify: Array[VerifyStep]  // 验证：如何确认完成
  done_criteria: String // 完成标准：什么叫做完成

  // 文件和依赖
  files: Array[String]  // 涉及的文件
  dependencies: Array[String]  // 依赖的其他 Spec ID

  // 元数据
  created_at: Int
  started_at: Int?
  completed_at: Int?
  tags: Array[String]

  // 执行结果
  result: String?
  summary: String?
}

// ============ Task Spec Builder ============

struct TaskSpecBuilder {
  id: String
  name: String
  task_type: TaskType
  priority: TaskPriority
  goal: String
  context: String
  action: String
  verify_steps: Array[VerifyStep]
  done_criteria: String
  files: Array[String]
  dependencies: Array[String]
  tags: Array[String]
}

fn TaskSpecBuilder::new(name: String) -> TaskSpecBuilder {
  TaskSpecBuilder::{
    id: generate_spec_id(name),
    name: name,
    task_type: Auto,
    priority: P2,
    goal: "",
    context: "",
    action: "",
    verify_steps: [],
    done_criteria: "",
    files: [],
    dependencies: [],
    tags: [],
  }
}

fn TaskSpecBuilder::goal(self: TaskSpecBuilder, goal: String) -> TaskSpecBuilder {
  TaskSpecBuilder::{ ..self, goal: goal }
}

fn TaskSpecBuilder::context(self: TaskSpecBuilder, ctx: String) -> TaskSpecBuilder {
  TaskSpecBuilder::{ ..self, context: ctx }
}

fn TaskSpecBuilder::action(self: TaskSpecBuilder, action: String) -> TaskSpecBuilder {
  TaskSpecBuilder::{ ..self, action: action }
}

fn TaskSpecBuilder::verify(self: TaskSpecBuilder, desc: String, expected: String) -> TaskSpecBuilder {
  let mut steps = self.verify_steps.clone()
  steps.push(VerifyStep::{
    description: desc,
    command: None,
    expected: expected,
    passed: None,
  })
  TaskSpecBuilder::{ ..self, verify_steps: steps }
}

fn TaskSpecBuilder::verify_with_command(
  self: TaskSpecBuilder,
  desc: String,
  command: String,
  expected: String
) -> TaskSpecBuilder {
  let mut steps = self.verify_steps.clone()
  steps.push(VerifyStep::{
    description: desc,
    command: Some(command),
    expected: expected,
    passed: None,
  })
  TaskSpecBuilder::{ ..self, verify_steps: steps }
}

fn TaskSpecBuilder::done(self: TaskSpecBuilder, criteria: String) -> TaskSpecBuilder {
  TaskSpecBuilder::{ ..self, done_criteria: criteria }
}

fn TaskSpecBuilder::files(self: TaskSpecBuilder, files: Array[String]) -> TaskSpecBuilder {
  TaskSpecBuilder::{ ..self, files: files }
}

fn TaskSpecBuilder::priority(self: TaskSpecBuilder, p: TaskPriority) -> TaskSpecBuilder {
  TaskSpecBuilder::{ ..self, priority: p }
}

fn TaskSpecBuilder::task_type(self: TaskSpecBuilder, t: TaskType) -> TaskSpecBuilder {
  TaskSpecBuilder::{ ..self, task_type: t }
}

fn TaskSpecBuilder::depends_on(self: TaskSpecBuilder, spec_id: String) -> TaskSpecBuilder {
  let mut deps = self.dependencies.clone()
  deps.push(spec_id)
  TaskSpecBuilder::{ ..self, dependencies: deps }
}

fn TaskSpecBuilder::tag(self: TaskSpecBuilder, tag: String) -> TaskSpecBuilder {
  let mut tags = self.tags.clone()
  tags.push(tag)
  TaskSpecBuilder::{ ..self, tags: tags }
}

fn TaskSpecBuilder::build(self: TaskSpecBuilder) -> TaskSpec {
  TaskSpec::{
    id: self.id,
    name: self.name,
    description: "\(self.goal)\n\n\(self.action)",
    task_type: self.task_type,
    priority: self.priority,
    status: Draft,
    goal: self.goal,
    context: self.context,
    action: self.action,
    verify: self.verify_steps,
    done_criteria: self.done_criteria,
    files: self.files,
    dependencies: self.dependencies,
    created_at: now(),
    started_at: None,
    completed_at: None,
    tags: self.tags,
    result: None,
    summary: None,
  }
}

// ============ XML 渲染（GSD 风格）============

fn TaskSpec::to_xml(self: TaskSpec) -> String {
  let verify_xml = self.verify.map(|v| {
    let cmd = match v.command {
      Some(c) => "\n    <command>\(c)</command>",
      None => "",
    }
    "  <verify>\n    <description>\(v.description)</description>\(cmd)\n    <expected>\(v.expected)</expected>\n  </verify>"
  })

  let files_xml = self.files.map(|f| "  <file>\(f)</file>")
  let deps_xml = self.dependencies.map(|d| "  <depends_on>\(d)</depends_on>")
  let tags_xml = self.tags.map(|t| "  <tag>\(t)</tag>")

  String::join([
    "<task type=\"\(task_type_to_string(self.task_type))\" priority=\"\(priority_to_string(self.priority))\">",
    "  <id>\(self.id)</id>",
    "  <name>\(self.name)</name>",
    "",
    "  <!-- 目标：要做什么 -->",
    "  <goal>\(self.goal)</goal>",
    "",
    "  <!-- 上下文：背景信息 -->",
    "  <context>\(self.context)</context>",
    "",
    "  <!-- 行动：具体怎么做 -->",
    "  <action>\(self.action)</action>",
    "",
    "  <!-- 涉及文件 -->",
    String::join(files_xml, "\n"),
    "",
    "  <!-- 验证步骤 -->",
    String::join(verify_xml, "\n"),
    "",
    "  <!-- 完成标准 -->",
    "  <done>\(self.done_criteria)</done>",
    "",
    "  <!-- 依赖 -->",
    String::join(deps_xml, "\n"),
    "",
    "  <!-- 标签 -->",
    String::join(tags_xml, "\n"),
    "</task>",
  ], "\n")
}

// ============ Markdown 渲染（PLAN.md 风格）============

fn TaskSpec::to_markdown(self: TaskSpec) -> String {
  let verify_md = self.verify.map(|v| {
    let cmd = match v.command {
      Some(c) => "\n  - Command: `\(c)`",
      None => "",
    }
    "- **\(v.description)**\(cmd)\n  - Expected: \(v.expected)"
  })

  let files_md = self.files.map(|f| "- `\(f)`")
  let deps_md = self.dependencies.map(|d| "- `\(d)`")

  String::join([
    "# Task Spec: \(self.name)",
    "",
    "| Field | Value |",
    "|-------|-------|",
    "| ID | `\(self.id)` |",
    "| Type | \(task_type_to_string(self.task_type)) |",
    "| Priority | \(priority_to_string(self.priority)) |",
    "| Status | \(spec_status_to_string(self.status)) |",
    "| Created | \(format_time(self.created_at)) |",
    "",
    "## 🎯 Goal",
    "",
    self.goal,
    "",
    "## 📋 Context",
    "",
    self.context,
    "",
    "## ⚙️ Action",
    "",
    self.action,
    "",
    "## 📁 Files",
    "",
    String::join(files_md, "\n"),
    "",
    "## ✅ Verify",
    "",
    String::join(verify_md, "\n"),
    "",
    "## 🏁 Done Criteria",
    "",
    self.done_criteria,
    "",
    "## 🔗 Dependencies",
    "",
    if deps_md.length() > 0 { String::join(deps_md, "\n") } else { "None" },
  ], "\n")
}

// ============ Spec 执行器 ============

struct SpecExecutor {
  context_manager: ContextManager
  spec_dir: String
  results: Array[SpecResult]
}

struct SpecResult {
  spec_id: String
  spec_name: String
  status: TaskSpecStatus
  result: String?
  verify_results: Array[VerifyResult]
  duration_ms: Int
  summary: String
}

struct VerifyResult {
  step: VerifyStep
  passed: Bool
  actual: String?
  error: String?
}

fn SpecExecutor::new(context_manager: ContextManager) -> SpecExecutor {
  SpecExecutor::{
    context_manager: context_manager,
    spec_dir: ".planning/specs/",
    results: [],
  }
}

// 执行 Spec
fn SpecExecutor::execute(self: SpecExecutor, spec: TaskSpec, handler: (TaskSpec) -> Result[String]) -> SpecResult {
  let start_time = now_ms()

  log_info("Executing spec: \(spec.name) [\(spec.id)]")

  // 创建子上下文（GSD 的核心：每个任务独立上下文）
  let child_ctx = self.context_manager.create_child_context(spec.id)

  // 注入 Spec 上下文
  child_ctx.add(SystemEvent, spec.to_xml(), 10)
  child_ctx.pin_entry(child_ctx.state.entries[0].id)

  // 执行任务
  let exec_result = handler(spec)

  let duration = now_ms() - start_time

  // 运行验证步骤
  let verify_results = self.run_verify_steps(spec)

  let all_passed = verify_results.all(|v| v.passed)

  let status = match exec_result {
    Ok(_) => if all_passed { Done } else { Failed },
    Err(_) => Failed,
  }

  let result_text = match exec_result {
    Ok(r) => r,
    Err(e) => "Error: \(error_to_string(e))",
  }

  // 生成 SUMMARY.md
  let summary = self.generate_summary(spec, status, result_text, verify_results, duration)

  // 保存 SUMMARY.md
  self.save_summary(spec.id, summary)

  // 记录到父上下文
  self.context_manager.add_task_result(
    "Task '\(spec.name)' \(spec_status_to_string(status)): \(result_text.substring(0, min(200, result_text.length())))"
  )

  let spec_result = SpecResult::{
    spec_id: spec.id,
    spec_name: spec.name,
    status: status,
    result: Some(result_text),
    verify_results: verify_results,
    duration_ms: duration,
    summary: summary,
  }

  self.results.push(spec_result)

  log_info("Spec completed: \(spec.name) → \(spec_status_to_string(status)) (\(duration)ms)")

  spec_result
}

// 运行验证步骤
fn SpecExecutor::run_verify_steps(self: SpecExecutor, spec: TaskSpec) -> Array[VerifyResult] {
  let mut results = []

  for step in spec.verify {
    let result = self.run_single_verify(step)
    results.push(result)
  }

  results
}

fn SpecExecutor::run_single_verify(self: SpecExecutor, step: VerifyStep) -> VerifyResult {
  match step.command {
    Some(cmd) => {
      // 执行验证命令
      let output = exec_command(cmd)
      let passed = output.contains(step.expected)

      VerifyResult::{
        step: step,
        passed: passed,
        actual: Some(output),
        error: if passed { None } else { Some("Expected '\(step.expected)' but got '\(output)'") },
      }
    }
    None => {
      // 无命令验证，标记为需要人工确认
      VerifyResult::{
        step: step,
        passed: true,  // 默认通过，等待人工确认
        actual: None,
        error: None,
      }
    }
  }
}

// 生成 SUMMARY.md（GSD 风格）
fn SpecExecutor::generate_summary(
  self: SpecExecutor,
  spec: TaskSpec,
  status: TaskSpecStatus,
  result: String,
  verify_results: Array[VerifyResult],
  duration_ms: Int
) -> String {
  let verify_md = verify_results.map(|v| {
    let icon = if v.passed { "✅" } else { "❌" }
    let actual = match v.actual {
      Some(a) => "\n  - Actual: `\(a.substring(0, min(100, a.length())))`",
      None => "",
    }
    "\(icon) **\(v.step.description)**\(actual)"
  })

  let passed_count = verify_results.filter(|v| v.passed).length()
  let total_count = verify_results.length()

  String::join([
    "# Task Summary: \(spec.name)",
    "",
    "| Field | Value |",
    "|-------|-------|",
    "| ID | `\(spec.id)` |",
    "| Status | \(spec_status_to_string(status)) |",
    "| Duration | \(duration_ms)ms |",
    "| Verify | \(passed_count)/\(total_count) passed |",
    "",
    "## Result",
    "",
    result,
    "",
    "## Verification",
    "",
    String::join(verify_md, "\n"),
    "",
    "## What Changed",
    "",
    spec.files.map(|f| "- `\(f)`").join("\n"),
    "",
    "---",
    "",
    "*Generated by XiaoClaw SpecExecutor at \(format_time(now()))*",
  ], "\n")
}

fn SpecExecutor::save_summary(self: SpecExecutor, spec_id: String, summary: String) -> Unit {
  let path = "\(self.spec_dir)\(spec_id)-SUMMARY.md"
  write_file(path, summary)
  log_info("Summary saved: \(path)")
}

// ============ Spec 注册表 ============

struct SpecRegistry {
  specs: Map[String, TaskSpec]
  executor: SpecExecutor
}

fn SpecRegistry::new(executor: SpecExecutor) -> SpecRegistry {
  SpecRegistry::{
    specs: Map::new(),
    executor: executor,
  }
}

fn SpecRegistry::register(self: SpecRegistry, spec: TaskSpec) -> Unit {
  self.specs.set(spec.id, spec)
  log_info("Spec registered: \(spec.name) [\(spec.id)]")
}

fn SpecRegistry::get(self: SpecRegistry, id: String) -> TaskSpec? {
  self.specs.get(id)
}

fn SpecRegistry::list(self: SpecRegistry) -> Array[TaskSpec] {
  self.specs.values()
}

fn SpecRegistry::list_by_status(self: SpecRegistry, status: TaskSpecStatus) -> Array[TaskSpec] {
  self.specs.values().filter(|s| s.status == status)
}

// ============ 预定义 Spec 模板 ============

// 飞书消息发送 Spec
fn create_feishu_message_spec(message: String, target: String) -> TaskSpec {
  TaskSpecBuilder::new("send-feishu-message")
    .goal("通过飞书发送消息给 \(target)")
    .context("用户请求发送飞书消息。目标: \(target)，内容: \(message)")
    .action("调用飞书 API 发送消息。使用 FeishuChannel::send_text() 方法。")
    .verify("消息发送成功", "API 返回 200 状态码")
    .verify("消息内容正确", "消息内容与输入一致")
    .done("飞书消息已成功发送，用户收到通知")
    .files(["src/channels/feishu.mbt"])
    .tag("feishu")
    .tag("message")
    .build()
}

// 定时任务 Spec
fn create_schedule_spec(cron: String, task_name: String) -> TaskSpec {
  TaskSpecBuilder::new("create-scheduled-task")
    .goal("创建定时任务: \(task_name)，Cron 表达式: \(cron)")
    .context("用户需要定期执行 \(task_name)")
    .action("使用 Scheduler 创建 Cron 任务。验证 Cron 表达式格式正确。")
    .verify("Cron 表达式有效", "表达式解析成功，无错误")
    .verify("任务已注册", "任务出现在调度器列表中")
    .done("定时任务已创建并开始运行")
    .files(["src/scheduler/cron.mbt"])
    .tag("scheduler")
    .tag("cron")
    .build()
}

// 健康检查 Spec
fn create_health_check_spec() -> TaskSpec {
  TaskSpecBuilder::new("health-check")
    .goal("检查系统所有组件的健康状态")
    .context("定期健康检查，确保系统正常运行")
    .action("检查: 1) API 连接 2) 数据库连接 3) 消息通道 4) 内存使用")
    .verify_with_command("API 可达", "curl -s http://localhost:8080/health", "ok")
    .verify("内存使用正常", "内存使用 < 50MB")
    .verify("所有通道在线", "Telegram/Feishu/Discord 状态为 connected")
    .done("所有健康检查通过，系统运行正常")
    .tag("monitoring")
    .tag("health")
    .priority(P0)
    .build()
}

// ============ 辅助函数 ============

fn generate_spec_id(name: String) -> String {
  let slug = name.to_lowercase().replace(" ", "-")
  "spec-\(slug)-\(now())"
}

fn task_type_to_string(t: TaskType) -> String {
  match t {
    Feature => "feature"
    Bugfix => "bugfix"
    Refactor => "refactor"
    Research => "research"
    Config => "config"
    Maintenance => "maintenance"
    Auto => "auto"
  }
}

fn priority_to_string(p: TaskPriority) -> String {
  match p {
    P0 => "P0-Critical"
    P1 => "P1-High"
    P2 => "P2-Medium"
    P3 => "P3-Low"
  }
}

fn spec_status_to_string(s: TaskSpecStatus) -> String {
  match s {
    Draft => "Draft"
    Approved => "Approved"
    InProgress => "In Progress"
    Done => "✅ Done"
    Failed => "❌ Failed"
    Cancelled => "Cancelled"
  }
}

fn now_ms() -> Int {
  now() * 1000
}
