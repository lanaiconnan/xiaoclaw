// XiaoClaw 日志系统

// 日志级别
enum LogLevel {
  Debug
  Info
  Warn
  Error
  Fatal
}

fn log_level_to_string(level: LogLevel) -> String {
  match level {
    Debug => "DEBUG"
    Info => "INFO "
    Warn => "WARN "
    Error => "ERROR"
    Fatal => "FATAL"
  }
}

// 日志条目
struct LogEntry {
  timestamp: Int
  level: LogLevel
  message: String
  source: String
}

fn LogEntry::new(level: LogLevel, message: String, source: String) -> LogEntry {
  LogEntry::{
    timestamp: now(),
    level: level,
    message: message,
    source: source,
  }
}

fn LogEntry::to_string(self: LogEntry) -> String {
  let ts = format_time(self.timestamp)
  let level_str = log_level_to_string(self.level)
  "[\(ts)] \(level_str) [\(self.source)] \(self.message)"
}

// 日志器
struct Logger {
  min_level: LogLevel
  outputs: Array[LoggerOutput]
}

trait LoggerOutput {
  fn write(self: Self, entry: LogEntry) -> Unit
}

struct ConsoleOutput
struct FileOutput { path: String }
struct BufferOutput { entries: Array[LogEntry] }

fn Logger::new(min_level: LogLevel) -> Logger {
  Logger::{
    min_level: min_level,
    outputs: [ConsoleOutput],
  }
}

fn Logger::add_output(self: Logger, output: LoggerOutput) -> Unit {
  self.outputs.push(output)
}

fn Logger::log(self: Logger, level: LogLevel, message: String, source: String) -> Unit {
  if self.should_log(level) {
    let entry = LogEntry::new(level, message, source)
    for output in self.outputs {
      output.write(entry)
    }
  }
}

fn Logger::should_log(self: Logger, level: LogLevel) -> Bool {
  let current = match level {
    Debug => 0
    Info => 1
    Warn => 2
    Error => 3
    Fatal => 4
  }
  
  let min = match self.min_level {
    Debug => 0
    Info => 1
    Warn => 2
    Error => 3
    Fatal => 4
  }
  
  current >= min
}

// 便捷方法
fn Logger::debug(self: Logger, msg: String) -> Unit {
  self.log(Debug, msg, "app")
}

fn Logger::info(self: Logger, msg: String) -> Unit {
  self.log(Info, msg, "app")
}

fn Logger::warn(self: Logger, msg: String) -> Unit {
  self.log(Warn, msg, "app")
}

fn Logger::error(self: Logger, msg: String) -> Unit {
  self.log(Error, msg, "app")
}

// ConsoleOutput 实现
impl LoggerOutput for ConsoleOutput {
  fn write(self: Self, entry: LogEntry) -> Unit {
    let line = entry.to_string()
    match entry.level {
      Debug => println("[DEBUG] \(line)")
      Info => println("[INFO ] \(line)")
      Warn => println("[WARN ] \(line)")
      Error => println("[ERROR] \(line)")
      Fatal => println("[FATAL] \(line)")
    }
  }
}

// 全局日志器
let global_logger = Logger::new(Info)

fn log_info(msg: String) -> Unit {
  global_logger.info(msg)
}

fn log_error(msg: String) -> Unit {
  global_logger.error(msg)
}

fn log_debug(msg: String) -> Unit {
  global_logger.debug(msg)
}

fn log_warn(msg: String) -> Unit {
  global_logger.warn(msg)
}
