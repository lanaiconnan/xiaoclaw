// XiaoClaw - CLI 测试
// 覆盖：命令解析、Flag 解析、子命令、边界检查

// ============ 命令解析测试 ============

fn test_parse_command_start() -> TestResult {
  let cmd = parse_command("start")
  let passed = cmd == Start
  { name: "parse_command::start", passed, message: if passed { "ok" } else { "解析失败" }, duration: 0 }
}

fn test_parse_command_start_alias() -> TestResult {
  // 🔴 Fix #9 验证：OR 语法用 || 替代
  let cmd = parse_command("s")
  let passed = cmd == Start
  { name: "parse_command::s → Start（Fix #9）", passed, message: if passed { "ok" } else { "别名解析失败" }, duration: 0 }
}

fn test_parse_command_stop() -> TestResult {
  let cmd = parse_command("stop")
  let passed = cmd == Stop
  { name: "parse_command::stop", passed, message: if passed { "ok" } else { "解析失败" }, duration: 0 }
}

fn test_parse_command_restart_aliases() -> TestResult {
  let cmd1 = parse_command("restart")
  let cmd2 = parse_command("reload")
  let passed = cmd1 == Restart && cmd2 == Restart
  { name: "parse_command::restart/reload → Restart", passed, message: if passed { "ok" } else { "别名解析失败" }, duration: 0 }
}

fn test_parse_command_config_aliases() -> TestResult {
  let cmd1 = parse_command("config")
  let cmd2 = parse_command("cfg")
  let passed = cmd1 == Config && cmd2 == Config
  { name: "parse_command::config/cfg → Config", passed, message: if passed { "ok" } else { "别名解析失败" }, duration: 0 }
}

fn test_parse_command_unknown() -> TestResult {
  let cmd = parse_command("unknown")
  let passed = cmd == Help
  { name: "parse_command::unknown → Help", passed, message: if passed { "ok" } else { "未知命令应返回 Help" }, duration: 0 }
}

fn test_parse_command_help_aliases() -> TestResult {
  let cmd1 = parse_command("help")
  let cmd2 = parse_command("h")
  let cmd3 = parse_command("?")
  let passed = cmd1 == Help && cmd2 == Help && cmd3 == Help
  { name: "parse_command::help/h/? → Help", passed, message: if passed { "ok" } else { "别名解析失败" }, duration: 0 }
}

// ============ Flag 解析测试 ============

fn test_parse_flags_verbose_long() -> TestResult {
  let ctx = CLIContext::new(["xiaoclaw", "start", "--verbose"])
  parse_flags(ctx)
  let passed = ctx.verbose == true
  { name: "parse_flags::--verbose（Fix #14）", passed, message: if passed { "ok" } else { "--verbose 未解析" }, duration: 0 }
}

fn test_parse_flags_verbose_short() -> TestResult {
  let ctx = CLIContext::new(["xiaoclaw", "start", "-v"])
  parse_flags(ctx)
  let passed = ctx.verbose == true
  { name: "parse_flags::-v", passed, message: if passed { "ok" } else { "-v 未解析" }, duration: 0 }
}

fn test_parse_flags_quiet() -> TestResult {
  let ctx = CLIContext::new(["xiaoclaw", "start", "--quiet"])
  parse_flags(ctx)
  let passed = ctx.quiet == true
  { name: "parse_flags::--quiet", passed, message: if passed { "ok" } else { "--quiet 未解析" }, duration: 0 }
}

fn test_parse_flags_json() -> TestResult {
  let ctx = CLIContext::new(["xiaoclaw", "status", "--json"])
  parse_flags(ctx)
  let passed = ctx.json == true
  { name: "parse_flags::--json", passed, message: if passed { "ok" } else { "--json 未解析" }, duration: 0 }
}

fn test_parse_flags_key_value() -> TestResult {
  // 🔴 Fix #14 验证：--key=value 格式
  let ctx = CLIContext::new(["xiaoclaw", "config", "--key=value123"])
  parse_flags(ctx)
  let passed = ctx.flags["key"] == "value123"
  { name: "parse_flags::--key=value（Fix #14）", passed, message: if passed { "ok" } else { "key=value 未解析" }, duration: 0 }
}

// ============ CLI 上下文测试 ============

fn test_cli_context_new() -> TestResult {
  let ctx = CLIContext::new(["xiaoclaw", "start"])
  let passed = ctx.args.length() == 2 &&
    ctx.verbose == false &&
    ctx.quiet == false &&
    ctx.json == false
  { name: "CLIContext::new 默认值", passed, message: if passed { "ok" } else { "默认值不正确" }, duration: 0 }
}

// ============ slice_array 测试 ============

fn test_slice_array_from_middle() -> TestResult {
  let arr = ["a", "b", "c", "d"]
  let sliced = slice_array(arr, 2)
  let passed = sliced.length() == 2 &&
    sliced[0] == "c" &&
    sliced[1] == "d"
  { name: "slice_array::中间截取", passed, message: if passed { "ok" } else { "截取不正确" }, duration: 0 }
}

fn test_slice_array_from_end() -> TestResult {
  let arr = ["a", "b"]
  let sliced = slice_array(arr, 2)
  let passed = sliced.length() == 0
  { name: "slice_array::越界返回空", passed, message: if passed { "ok" } else { "越界应返回空数组" }, duration: 0 }
}

fn test_slice_array_empty() -> TestResult {
  let arr : Array[String] = []
  let sliced = slice_array(arr, 0)
  let passed = sliced.length() == 0
  { name: "slice_array::空数组", passed, message: if passed { "ok" } else { "空数组应返回空" }, duration: 0 }
}

// ============ 辅助函数测试 ============

fn test_is_sensitive_token() -> TestResult {
  let passed = is_sensitive("TELEGRAM_TOKEN") == true
  { name: "is_sensitive::TOKEN", passed, message: if passed { "ok" } else { "TOKEN 应敏感" }, duration: 0 }
}

fn test_is_sensitive_key() -> TestResult {
  let passed = is_sensitive("API_KEY") == true
  { name: "is_sensitive::KEY", passed, message: if passed { "ok" } else { "KEY 应敏感" }, duration: 0 }
}

fn test_is_sensitive_password() -> TestResult {
  let passed = is_sensitive("USER_PASSWORD") == true
  { name: "is_sensitive::PASSWORD", passed, message: if passed { "ok" } else { "PASSWORD 应敏感" }, duration: 0 }
}

fn test_is_sensitive_normal() -> TestResult {
  let passed = is_sensitive("MODEL_NAME") == false
  { name: "is_sensitive::正常配置不敏感", passed, message: if passed { "ok" } else { "MODEL_NAME 不应敏感" }, duration: 0 }
}

fn test_generate_id() -> TestResult {
  let id1 = generate_id()
  let id2 = generate_id()
  // ID 应以 "task-" 开头
  let passed = id1.starts_with("task-") && id2.starts_with("task-")
  { name: "generate_id::格式正确", passed, message: if passed { "ok" } else { "ID 格式不正确" }, duration: 0 }
}

// ============ 命令执行测试（不检查输出，只检查不 panic）============

fn test_cli_main_no_args() -> TestResult {
  let _ = cli_main(["xiaoclaw"])
  let passed = true
  { name: "cli_main::无参数不 panic", passed, message: if passed { "ok" } else { "panic 了" }, duration: 0 }
}

fn test_cli_main_help() -> TestResult {
  let _ = cli_main(["xiaoclaw", "help"])
  let passed = true
  { name: "cli_main::help 不 panic", passed, message: if passed { "ok" } else { "panic 了" }, duration: 0 }
}

fn test_cli_main_version() -> TestResult {
  let _ = cli_main(["xiaoclaw", "version"])
  let passed = true
  { name: "cli_main::version 不 panic", passed, message: if passed { "ok" } else { "panic 了" }, duration: 0 }
}

fn test_cli_main_status_json() -> TestResult {
  let _ = cli_main(["xiaoclaw", "status", "--json"])
  let passed = true
  { name: "cli_main::status --json 不 panic", passed, message: if passed { "ok" } else { "panic 了" }, duration: 0 }
}

fn test_cli_main_test_run() -> TestResult {
  let _ = cli_main(["xiaoclaw", "test", "run"])
  let passed = true
  { name: "cli_main::test run 不 panic", passed, message: if passed { "ok" } else { "panic 了" }, duration: 0 }
}

fn test_cli_main_benchmark() -> TestResult {
  let _ = cli_main(["xiaoclaw", "benchmark"])
  let passed = true
  { name: "cli_main::benchmark 不 panic", passed, message: if passed { "ok" } else { "panic 了" }, duration: 0 }
}

// ============ 测试套件注册 ============

fn cli_test_suite() -> TestSuite {
  TestSuite::{
    name: "CLI",
    tests: [
      test_parse_command_start,
      test_parse_command_start_alias,
      test_parse_command_stop,
      test_parse_command_restart_aliases,
      test_parse_command_config_aliases,
      test_parse_command_unknown,
      test_parse_command_help_aliases,
      test_parse_flags_verbose_long,
      test_parse_flags_verbose_short,
      test_parse_flags_quiet,
      test_parse_flags_json,
      test_parse_flags_key_value,
      test_cli_context_new,
      test_slice_array_from_middle,
      test_slice_array_from_end,
      test_slice_array_empty,
      test_is_sensitive_token,
      test_is_sensitive_key,
      test_is_sensitive_password,
      test_is_sensitive_normal,
      test_generate_id,
      test_cli_main_no_args,
      test_cli_main_help,
      test_cli_main_version,
      test_cli_main_status_json,
      test_cli_main_test_run,
      test_cli_main_benchmark,
    ],
    setup: None,
    teardown: None,
  }
}
