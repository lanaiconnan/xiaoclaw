// XiaoClaw - Jobs System 测试
// 覆盖：JobBuilder、JobQueue、Verify 条件、优先级、重试、取消

// ============ JobBuilder 测试 ============

fn test_job_builder_basic() -> TestResult {
  let job = JobBuilder::new("j1", "测试 Job")
    .with_description("描述")
    .with_priority(High)
    .with_retries(5)
    .with_tag("test")
    .build(fn() { Ok("done") })

  let passed = job.id == "j1" &&
    job.name == "测试 Job" &&
    job.description == "描述" &&
    job.priority == High &&
    job.max_retries == 5 &&
    job.tags.contains("test") &&
    job.status == Pending

  { name: "JobBuilder::基础构建", passed, message: if passed { "ok" } else { "字段不匹配" }, duration: 0 }
}

fn test_job_builder_verify_conditions() -> TestResult {
  let job = JobBuilder::new("j2", "Verify Job")
    .verify_output_contains("包含 ok", "ok")
    .verify_output_equals("等于 done", "done")
    .verify_custom("自定义", fn() { true })
    .build(fn() { Ok("ok") })

  let passed = job.verify_conditions.length() == 3 &&
    job.verify_conditions[0].required == true &&
    job.verify_conditions[1].required == true &&
    job.verify_conditions[2].required == true

  { name: "JobBuilder::Verify 条件构建", passed, message: if passed { "ok" } else { "verify_conditions 不正确" }, duration: 0 }
}

fn test_job_builder_optional_verify() -> TestResult {
  let job = JobBuilder::new("j3", "Optional Verify")
    .verify_optional("可选检查", OutputContains("maybe"))
    .build(fn() { Ok("result") })

  let passed = job.verify_conditions.length() == 1 &&
    job.verify_conditions[0].required == false

  { name: "JobBuilder::可选 Verify 条件", passed, message: if passed { "ok" } else { "required 应为 false" }, duration: 0 }
}

// ============ run_single_verify 测试 ============

fn test_verify_output_contains_pass() -> TestResult {
  let cond = JobVerifyCondition::new("包含 hello", OutputContains("hello"))
  let result = run_single_verify(cond, "hello world")
  { name: "Verify::OutputContains 通过", passed: result.passed, message: if result.passed { "ok" } else { result.error.or("") }, duration: 0 }
}

fn test_verify_output_contains_fail() -> TestResult {
  let cond = JobVerifyCondition::new("包含 xyz", OutputContains("xyz"))
  let result = run_single_verify(cond, "hello world")
  let passed = not(result.passed) && result.error.is_some()
  { name: "Verify::OutputContains 失败", passed, message: if passed { "ok" } else { "应该失败但通过了" }, duration: 0 }
}

fn test_verify_output_equals_pass() -> TestResult {
  let cond = JobVerifyCondition::new("等于 exact", OutputEquals("exact"))
  let result = run_single_verify(cond, "exact")
  { name: "Verify::OutputEquals 通过", passed: result.passed, message: if result.passed { "ok" } else { result.error.or("") }, duration: 0 }
}

fn test_verify_output_equals_fail() -> TestResult {
  let cond = JobVerifyCondition::new("等于 exact", OutputEquals("exact"))
  let result = run_single_verify(cond, "not exact")
  let passed = not(result.passed)
  { name: "Verify::OutputEquals 失败", passed, message: if passed { "ok" } else { "应该失败但通过了" }, duration: 0 }
}

fn test_verify_output_matches_pass() -> TestResult {
  let cond = JobVerifyCondition::new("前缀 hello", OutputMatches("hello"))
  let result = run_single_verify(cond, "hello world")
  { name: "Verify::OutputMatches 通过", passed: result.passed, message: if result.passed { "ok" } else { result.error.or("") }, duration: 0 }
}

fn test_verify_custom_pass() -> TestResult {
  let cond = JobVerifyCondition::new("长度大于5", Custom(fn() { true }))
  let result = run_single_verify(cond, "hello world")
  { name: "Verify::Custom 通过", passed: result.passed, message: if result.passed { "ok" } else { result.error.or("") }, duration: 0 }
}

fn test_verify_custom_fail() -> TestResult {
  let cond = JobVerifyCondition::new("永远失败", Custom(fn() { false }))
  let result = run_single_verify(cond, "anything")
  let passed = not(result.passed) && result.error.is_some()
  { name: "Verify::Custom 失败", passed, message: if passed { "ok" } else { "应该失败但通过了" }, duration: 0 }
}

fn test_verify_no_verify() -> TestResult {
  let cond = JobVerifyCondition::new("无验证", NoVerify)
  let result = run_single_verify(cond, "anything")
  { name: "Verify::NoVerify 始终通过", passed: result.passed, message: if result.passed { "ok" } else { "NoVerify 应该始终通过" }, duration: 0 }
}

// ============ pow2 测试（指数退避修复验证）============

fn test_pow2_correctness() -> TestResult {
  let passed = pow2(0) == 1 &&
    pow2(1) == 2 &&
    pow2(2) == 4 &&
    pow2(3) == 8 &&
    pow2(4) == 16

  { name: "pow2::指数退避计算正确", passed, message: if passed { "ok" } else { "pow2 计算错误，退避延迟不正确" }, duration: 0 }
}

fn test_retry_delays_not_xor() -> TestResult {
  // 验证 pow2(1)=2, pow2(2)=4 而不是 XOR 结果
  // 2 XOR 0 = 2, 2 XOR 1 = 3, 2 XOR 2 = 0 (错误的旧实现)
  // pow2(0)=1, pow2(1)=2, pow2(2)=4 (正确的新实现)
  let delay_1 = 100 * pow2(0)  // 第1次重试: 100ms
  let delay_2 = 100 * pow2(1)  // 第2次重试: 200ms
  let delay_3 = 100 * pow2(2)  // 第3次重试: 400ms

  let passed = delay_1 == 100 && delay_2 == 200 && delay_3 == 400

  { name: "pow2::退避序列 100/200/400ms", passed, message: if passed { "ok" } else { "退避序列错误: \(delay_1)/\(delay_2)/\(delay_3)" }, duration: 0 }
}

// ============ JobQueue 测试 ============

fn test_queue_enqueue_and_stats() -> TestResult {
  let queue = JobQueue::new(2)
  let job1 = JobBuilder::new("q1", "Job 1").build(fn() { Ok("done") })
  let job2 = JobBuilder::new("q2", "Job 2").build(fn() { Ok("done") })

  queue.enqueue(job1)
  queue.enqueue(job2)

  let stats = queue.get_stats()
  let passed = stats.total == 2 && stats.pending == 2 && stats.max_concurrent == 2

  { name: "JobQueue::入队和统计", passed, message: if passed { "ok" } else { "stats 不正确: total=\(stats.total) pending=\(stats.pending)" }, duration: 0 }
}

fn test_queue_cancel_pending_job() -> TestResult {
  let queue = JobQueue::new(2)
  let job = JobBuilder::new("cancel-1", "待取消").build(fn() { Ok("done") })
  queue.enqueue(job)

  let cancelled = queue.cancel_job("cancel-1")
  let passed = cancelled && job.status == Cancelled

  { name: "JobQueue::取消 Pending Job", passed, message: if passed { "ok" } else { "取消失败或状态不对" }, duration: 0 }
}

fn test_queue_cancel_nonexistent() -> TestResult {
  let queue = JobQueue::new(2)
  let cancelled = queue.cancel_job("nonexistent")
  { name: "JobQueue::取消不存在的 Job 返回 false", passed: not(cancelled), message: if not(cancelled) { "ok" } else { "应该返回 false" }, duration: 0 }
}

fn test_queue_get_job() -> TestResult {
  let queue = JobQueue::new(2)
  let job = JobBuilder::new("get-1", "Get Job").build(fn() { Ok("done") })
  queue.enqueue(job)

  let found = queue.get_job("get-1")
  let not_found = queue.get_job("nonexistent")

  let passed = found.is_some() && not_found.is_none()
  { name: "JobQueue::get_job 查找", passed, message: if passed { "ok" } else { "查找结果不正确" }, duration: 0 }
}

fn test_queue_priority_sort() -> TestResult {
  let queue = JobQueue::new(4)

  let low  = JobBuilder::new("low",  "低优先级").with_priority(Low).build(fn() { Ok("low") })
  let high = JobBuilder::new("high", "高优先级").with_priority(Critical).build(fn() { Ok("high") })
  let norm = JobBuilder::new("norm", "普通优先级").with_priority(Normal).build(fn() { Ok("norm") })

  // 故意乱序入队
  queue.enqueue(low)
  queue.enqueue(norm)
  queue.enqueue(high)

  // 排序后 Critical 应该在最前
  queue.sort_by_priority()

  let first = queue.jobs[0]
  let passed = first.priority == Critical

  { name: "JobQueue::优先级排序（Critical 最先）", passed, message: if passed { "ok" } else { "排序后第一个不是 Critical" }, duration: 0 }
}

fn test_queue_execute_success() -> TestResult {
  let queue = JobQueue::new(2)
  queue.start()

  let job = JobBuilder::new("exec-1", "成功执行")
    .build(fn() { Ok("success output") })

  queue.enqueue(job)
  queue.process_next()

  let passed = job.status == Completed && job.result == Some("success output")
  queue.stop()

  { name: "JobQueue::成功执行 Job", passed, message: if passed { "ok" } else { "status=\(status_to_string(job.status)) result=\(job.result.or("None"))" }, duration: 0 }
}

fn test_queue_execute_failure() -> TestResult {
  let queue = JobQueue::new(2)
  queue.start()

  let job = JobBuilder::new("exec-fail", "失败执行")
    .with_retries(1)
    .build(fn() { Err("intentional error") })

  queue.enqueue(job)
  queue.process_next()

  let passed = job.status == Failed && job.error.is_some()
  queue.stop()

  { name: "JobQueue::失败 Job 状态为 Failed", passed, message: if passed { "ok" } else { "status=\(status_to_string(job.status))" }, duration: 0 }
}

fn test_queue_verify_pass_completes() -> TestResult {
  let queue = JobQueue::new(2)
  queue.start()

  let job = JobBuilder::new("verify-pass", "Verify 通过")
    .verify_output_contains("包含 hello", "hello")
    .build(fn() { Ok("hello world") })

  queue.enqueue(job)
  queue.process_next()

  let passed = job.status == Completed && job.verify_passed == Some(true)
  queue.stop()

  { name: "JobQueue::Verify 通过 → Completed", passed, message: if passed { "ok" } else { "status=\(status_to_string(job.status)) verify=\(job.verify_passed.map(fn(b){ b.to_string() }).or("None"))" }, duration: 0 }
}

fn test_queue_required_verify_fail_fails_job() -> TestResult {
  let queue = JobQueue::new(2)
  queue.start()

  let job = JobBuilder::new("verify-fail", "必要 Verify 失败")
    .verify_output_contains("包含 xyz", "xyz")
    .build(fn() { Ok("hello world") })

  queue.enqueue(job)
  queue.process_next()

  let passed = job.status == Failed && job.verify_passed == Some(false)
  queue.stop()

  { name: "JobQueue::必要 Verify 失败 → Failed", passed, message: if passed { "ok" } else { "status=\(status_to_string(job.status))" }, duration: 0 }
}

fn test_queue_optional_verify_fail_still_completes() -> TestResult {
  let queue = JobQueue::new(2)
  queue.start()

  let job = JobBuilder::new("verify-opt", "可选 Verify 失败")
    .verify_optional("可选检查", OutputContains("xyz"))
    .build(fn() { Ok("hello world") })

  queue.enqueue(job)
  queue.process_next()

  // 可选 verify 失败，Job 仍然 Completed
  let passed = job.status == Completed
  queue.stop()

  { name: "JobQueue::可选 Verify 失败 → 仍然 Completed", passed, message: if passed { "ok" } else { "status=\(status_to_string(job.status))" }, duration: 0 }
}

// ============ 测试套件注册 ============

fn jobs_test_suite() -> TestSuite {
  TestSuite::{
    name: "Jobs System",
    tests: [
      test_job_builder_basic,
      test_job_builder_verify_conditions,
      test_job_builder_optional_verify,
      test_verify_output_contains_pass,
      test_verify_output_contains_fail,
      test_verify_output_equals_pass,
      test_verify_output_equals_fail,
      test_verify_output_matches_pass,
      test_verify_custom_pass,
      test_verify_custom_fail,
      test_verify_no_verify,
      test_pow2_correctness,
      test_retry_delays_not_xor,
      test_queue_enqueue_and_stats,
      test_queue_cancel_pending_job,
      test_queue_cancel_nonexistent,
      test_queue_get_job,
      test_queue_priority_sort,
      test_queue_execute_success,
      test_queue_execute_failure,
      test_queue_verify_pass_completes,
      test_queue_required_verify_fail_fails_job,
      test_queue_optional_verify_fail_still_completes,
    ],
    setup: None,
    teardown: None,
  }
}
