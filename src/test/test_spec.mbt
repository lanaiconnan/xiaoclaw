// XiaoClaw - Task Spec 测试
// 覆盖：Builder、XML/Markdown 渲染、SpecExecutor、SpecRegistry

// ============ TaskSpecBuilder 测试 ============

fn test_spec_builder_basic() -> TestResult {
  let spec = TaskSpecBuilder::new("测试任务")
    .goal("实现功能 X")
    .context("背景信息")
    .action("具体步骤")
    .done("功能完成")
    .build()

  let passed = spec.name == "测试任务" &&
    spec.goal == "实现功能 X" &&
    spec.context == "背景信息" &&
    spec.action == "具体步骤" &&
    spec.done_criteria == "功能完成" &&
    spec.status == Draft &&
    spec.task_type == Auto &&
    spec.priority == P2

  { name: "TaskSpecBuilder::基础构建", passed, message: if passed { "ok" } else { "字段不匹配" }, duration: 0 }
}

fn test_spec_builder_verify_steps() -> TestResult {
  let spec = TaskSpecBuilder::new("验证任务")
    .verify("步骤1", "期望结果1")
    .verify("步骤2", "期望结果2")
    .verify_with_command("步骤3", "echo ok", "ok")
    .build()

  let passed = spec.verify.length() == 3 &&
    spec.verify[0].description == "步骤1" &&
    spec.verify[0].command.is_empty() &&
    spec.verify[2].command == Some("echo ok")

  { name: "TaskSpecBuilder::Verify 步骤构建", passed, message: if passed { "ok" } else { "verify 步骤不正确" }, duration: 0 }
}

fn test_spec_builder_dependencies() -> TestResult {
  let spec = TaskSpecBuilder::new("依赖任务")
    .depends_on("spec-001")
    .depends_on("spec-002")
    .build()

  let passed = spec.dependencies.length() == 2 &&
    spec.dependencies.contains("spec-001") &&
    spec.dependencies.contains("spec-002")

  { name: "TaskSpecBuilder::依赖关系构建", passed, message: if passed { "ok" } else { "dependencies 不正确" }, duration: 0 }
}

fn test_spec_builder_tags() -> TestResult {
  let spec = TaskSpecBuilder::new("标签任务")
    .tag("feishu")
    .tag("message")
    .build()

  let passed = spec.tags.length() == 2 &&
    spec.tags.contains("feishu") &&
    spec.tags.contains("message")

  { name: "TaskSpecBuilder::标签构建", passed, message: if passed { "ok" } else { "tags 不正确" }, duration: 0 }
}

fn test_spec_builder_priority() -> TestResult {
  let spec = TaskSpecBuilder::new("高优先级任务")
    .priority(P0)
    .build()

  let passed = spec.priority == P0

  { name: "TaskSpecBuilder::优先级设置", passed, message: if passed { "ok" } else { "priority 不正确" }, duration: 0 }
}

fn test_spec_builder_files() -> TestResult {
  let spec = TaskSpecBuilder::new("文件任务")
    .files(["src/a.mbt", "src/b.mbt"])
    .build()

  let passed = spec.files.length() == 2 &&
    spec.files.contains("src/a.mbt")

  { name: "TaskSpecBuilder::文件列表构建", passed, message: if passed { "ok" } else { "files 不正确" }, duration: 0 }
}

// ============ XML 渲染测试 ============

fn test_spec_to_xml_contains_key_fields() -> TestResult {
  let spec = TaskSpecBuilder::new("XML 测试")
    .goal("测试目标")
    .action("测试行动")
    .verify("验证步骤", "期望结果")
    .done("完成标准")
    .build()

  let xml = spec.to_xml()

  let passed = xml.contains("<task") &&
    xml.contains("<goal>测试目标</goal>") &&
    xml.contains("<action>测试行动</action>") &&
    xml.contains("<verify>") &&
    xml.contains("<done>完成标准</done>") &&
    xml.contains("</task>")

  { name: "TaskSpec::to_xml 包含关键字段", passed, message: if passed { "ok" } else { "XML 输出不完整" }, duration: 0 }
}

fn test_spec_to_xml_with_command() -> TestResult {
  let spec = TaskSpecBuilder::new("命令验证")
    .verify_with_command("API 可达", "curl http://localhost/health", "ok")
    .build()

  let xml = spec.to_xml()
  let passed = xml.contains("<command>curl http://localhost/health</command>")

  { name: "TaskSpec::to_xml 包含 command 字段", passed, message: if passed { "ok" } else { "command 字段缺失" }, duration: 0 }
}

fn test_spec_to_markdown_contains_sections() -> TestResult {
  let spec = TaskSpecBuilder::new("Markdown 测试")
    .goal("测试目标")
    .context("测试背景")
    .action("测试行动")
    .verify("验证步骤", "期望结果")
    .done("完成标准")
    .build()

  let md = spec.to_markdown()

  let passed = md.contains("# Task Spec:") &&
    md.contains("## 🎯 Goal") &&
    md.contains("## 📋 Context") &&
    md.contains("## ⚙️ Action") &&
    md.contains("## ✅ Verify") &&
    md.contains("## 🏁 Done Criteria")

  { name: "TaskSpec::to_markdown 包含所有章节", passed, message: if passed { "ok" } else { "Markdown 章节缺失" }, duration: 0 }
}

// ============ 辅助函数测试 ============

fn test_spec_status_to_string() -> TestResult {
  // 🟡 Fix #7 验证：状态字符串不带 emoji
  let passed = spec_status_to_string(Done) == "Done" &&
    spec_status_to_string(Failed) == "Failed" &&
    spec_status_to_string(Draft) == "Draft" &&
    spec_status_to_string(InProgress) == "InProgress"

  { name: "spec_status_to_string::不含 emoji（Fix #7）", passed, message: if passed { "ok" } else { "状态字符串含 emoji，会影响比较" }, duration: 0 }
}

fn test_spec_status_display_has_emoji() -> TestResult {
  // 显示层函数应该有 emoji
  let passed = spec_status_display(Done).contains("✅") &&
    spec_status_display(Failed).contains("❌")

  { name: "spec_status_display::含 emoji（显示层）", passed, message: if passed { "ok" } else { "显示层缺少 emoji" }, duration: 0 }
}

fn test_task_priority_to_string() -> TestResult {
  let passed = task_priority_to_string(P0) == "P0-Critical" &&
    task_priority_to_string(P1) == "P1-High" &&
    task_priority_to_string(P2) == "P2-Medium" &&
    task_priority_to_string(P3) == "P3-Low"

  { name: "task_priority_to_string::优先级字符串正确", passed, message: if passed { "ok" } else { "优先级字符串不正确" }, duration: 0 }
}

// ============ SpecExecutor 测试 ============

fn test_spec_executor_success() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let executor = SpecExecutor::new(ctx)

  let spec = TaskSpecBuilder::new("执行测试")
    .goal("测试执行")
    .done("执行完成")
    .build()

  let result = executor.execute(spec, fn(s) { Ok("executed: \(s.goal)") })

  let passed = result.status == Done &&
    result.result == Some("executed: 测试执行")

  { name: "SpecExecutor::成功执行", passed, message: if passed { "ok" } else { "status=\(spec_status_to_string(result.status))" }, duration: 0 }
}

fn test_spec_executor_failure() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let executor = SpecExecutor::new(ctx)

  let spec = TaskSpecBuilder::new("失败测试")
    .goal("测试失败")
    .done("不会完成")
    .build()

  let result = executor.execute(spec, fn(_s) { Err("intentional error") })

  let passed = result.status == Failed

  { name: "SpecExecutor::失败执行", passed, message: if passed { "ok" } else { "status=\(spec_status_to_string(result.status))" }, duration: 0 }
}

fn test_spec_executor_no_panic_on_empty_context() -> TestResult {
  // 🔴 Fix #1 验证：空 context 不 panic
  let ctx = ContextManager::new("empty", 10000)
  let executor = SpecExecutor::new(ctx)

  let spec = TaskSpecBuilder::new("空上下文测试").build()

  // 不应该 panic
  let result = executor.execute(spec, fn(_s) { Ok("ok") })
  let passed = result.status == Done

  { name: "SpecExecutor::空 context 不 panic（Fix #1）", passed, message: if passed { "ok" } else { "panic 了" }, duration: 0 }
}

fn test_spec_executor_wasm_verify_skipped() -> TestResult {
  // 🔴 Fix #2 验证：WASM 环境下命令验证被跳过而非 panic
  let ctx = ContextManager::new("test", 10000)
  let executor = SpecExecutor::new(ctx)

  let spec = TaskSpecBuilder::new("命令验证测试")
    .verify_with_command("API 可达", "curl http://localhost/health", "ok")
    .build()

  // 不应该 panic，命令验证应该被跳过
  let result = executor.execute(spec, fn(_s) { Ok("ok") })
  let passed = result.status == Done &&
    result.verify_results.length() == 1 &&
    result.verify_results[0].passed == true  // 跳过 = 通过

  { name: "SpecExecutor::WASM 命令验证跳过不 panic（Fix #2）", passed, message: if passed { "ok" } else { "panic 或状态不对" }, duration: 0 }
}

// ============ SpecRegistry 测试 ============

fn test_spec_registry_register_and_get() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let executor = SpecExecutor::new(ctx)
  let registry = SpecRegistry::new(executor)

  let spec = TaskSpecBuilder::new("注册测试").build()
  let spec_id = spec.id

  registry.register(spec)

  let found = registry.get(spec_id)
  let not_found = registry.get("nonexistent")

  let passed = found.is_some() && not_found.is_none()

  { name: "SpecRegistry::注册和查找", passed, message: if passed { "ok" } else { "查找结果不正确" }, duration: 0 }
}

fn test_spec_registry_list() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let executor = SpecExecutor::new(ctx)
  let registry = SpecRegistry::new(executor)

  registry.register(TaskSpecBuilder::new("任务1").build())
  registry.register(TaskSpecBuilder::new("任务2").build())
  registry.register(TaskSpecBuilder::new("任务3").build())

  let all = registry.list()
  let passed = all.length() == 3

  { name: "SpecRegistry::list 返回所有 Spec", passed, message: if passed { "ok" } else { "length=\(all.length())" }, duration: 0 }
}

fn test_spec_registry_list_by_status() -> TestResult {
  let ctx = ContextManager::new("test", 10000)
  let executor = SpecExecutor::new(ctx)
  let registry = SpecRegistry::new(executor)

  let spec1 = TaskSpecBuilder::new("草稿1").build()
  let mut spec2 = TaskSpecBuilder::new("完成1").build()
  spec2.status = Done

  registry.register(spec1)
  registry.register(spec2)

  let drafts = registry.list_by_status(Draft)
  let done   = registry.list_by_status(Done)

  let passed = drafts.length() == 1 && done.length() == 1

  { name: "SpecRegistry::按状态过滤", passed, message: if passed { "ok" } else { "drafts=\(drafts.length()) done=\(done.length())" }, duration: 0 }
}

// ============ 预定义模板测试 ============

fn test_predefined_feishu_spec() -> TestResult {
  let spec = create_feishu_message_spec("你好", "张三")
  let passed = spec.name == "send-feishu-message" &&
    spec.goal.contains("张三") &&
    spec.verify.length() >= 2 &&
    spec.tags.contains("feishu")

  { name: "预定义::飞书消息 Spec", passed, message: if passed { "ok" } else { "飞书 Spec 字段不正确" }, duration: 0 }
}

fn test_predefined_health_check_spec() -> TestResult {
  let spec = create_health_check_spec()
  let passed = spec.priority == P0 &&
    spec.tags.contains("monitoring") &&
    spec.verify.length() >= 3

  { name: "预定义::健康检查 Spec", passed, message: if passed { "ok" } else { "健康检查 Spec 字段不正确" }, duration: 0 }
}

// ============ 测试套件注册 ============

fn spec_test_suite() -> TestSuite {
  TestSuite::{
    name: "Task Spec",
    tests: [
      test_spec_builder_basic,
      test_spec_builder_verify_steps,
      test_spec_builder_dependencies,
      test_spec_builder_tags,
      test_spec_builder_priority,
      test_spec_builder_files,
      test_spec_to_xml_contains_key_fields,
      test_spec_to_xml_with_command,
      test_spec_to_markdown_contains_sections,
      test_spec_status_to_string,
      test_spec_status_display_has_emoji,
      test_task_priority_to_string,
      test_spec_executor_success,
      test_spec_executor_failure,
      test_spec_executor_no_panic_on_empty_context,
      test_spec_executor_wasm_verify_skipped,
      test_spec_registry_register_and_get,
      test_spec_registry_list,
      test_spec_registry_list_by_status,
      test_predefined_feishu_spec,
      test_predefined_health_check_spec,
    ],
    setup: None,
    teardown: None,
  }
}
