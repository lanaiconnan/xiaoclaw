// XiaoClaw 错误处理模块 v2.0

// 错误类型
enum Error {
  // 配置错误
  ConfigNotFound(String)
  ConfigInvalid(String)
  ConfigMissingKey(String)
  
  // 网络错误
  NetworkError(String)
  HttpError(Int, String)
  Timeout(Int)  // 超时时间(毫秒)
  ConnectionRefused(String)
  
  // API 错误
  ApiError(String)
  AuthError(String)
  AuthExpired
  RateLimitError(Int)  // 重试等待时间(秒)
  InvalidRequest(String)
  
  // 存储错误
  StorageError(String)
  DatabaseError(String)
  DatabaseConnectionFailed(String)
  QueryError(String)
  
  // 通道错误
  ChannelError(String)
  ChannelNotConnected(String)
  ChannelDisconnected(String)
  MessageSendFailed(String)
  MessageParseError(String)
  
  // 插件错误
  PluginError(String)
  PluginNotFound(String)
  PluginLoadFailed(String)
  PluginInitFailed(String)
  
  // 通用错误
  Unknown(String)
  NotImplemented
  InvalidInput(String)
  OutOfBounds(Int, Int)  // index, length
}

// 错误码
fn error_code(err: Error) -> String {
  match err {
    ConfigNotFound(_) => "E001"
    ConfigInvalid(_) => "E002"
    ConfigMissingKey(_) => "E003"
    NetworkError(_) => "E101"
    HttpError(_, _) => "E102"
    Timeout(_) => "E103"
    ConnectionRefused(_) => "E104"
    ApiError(_) => "E201"
    AuthError(_) => "E202"
    AuthExpired => "E203"
    RateLimitError(_) => "E204"
    InvalidRequest(_) => "E205"
    StorageError(_) => "E301"
    DatabaseError(_) => "E302"
    DatabaseConnectionFailed(_) => "E303"
    QueryError(_) => "E304"
    ChannelError(_) => "E401"
    ChannelNotConnected(_) => "E402"
    ChannelDisconnected(_) => "E403"
    MessageSendFailed(_) => "E404"
    MessageParseError(_) => "E405"
    PluginError(_) => "E501"
    PluginNotFound(_) => "E502"
    PluginLoadFailed(_) => "E503"
    PluginInitFailed(_) => "E504"
    Unknown(_) => "E999"
    NotImplemented => "E998"
    InvalidInput(_) => "E997"
    OutOfBounds(_, _) => "E996"
  }
}

// 错误信息
fn error_message(err: Error) -> String {
  match err {
    ConfigNotFound(key) => "Configuration not found: \(key)"
    ConfigInvalid(msg) => "Invalid configuration: \(msg)"
    ConfigMissingKey(key) => "Missing required configuration key: \(key)"
    NetworkError(msg) => "Network error: \(msg)"
    HttpError(code, msg) => "HTTP error \(code): \(msg)"
    Timeout(ms) => "Request timed out after \(ms)ms"
    ConnectionRefused(addr) => "Connection refused: \(addr)"
    ApiError(msg) => "API error: \(msg)"
    AuthError(msg) => "Authentication error: \(msg)"
    AuthExpired => "Authentication expired, please re-authenticate"
    RateLimitError(wait) => "Rate limited, retry after \(wait) seconds"
    InvalidRequest(msg) => "Invalid request: \(msg)"
    StorageError(msg) => "Storage error: \(msg)"
    DatabaseError(msg) => "Database error: \(msg)"
    DatabaseConnectionFailed(path) => "Failed to connect to database: \(path)"
    QueryError(sql) => "Query error: \(sql)"
    ChannelError(msg) => "Channel error: \(msg)"
    ChannelNotConnected(name) => "Channel not connected: \(name)"
    ChannelDisconnected(name) => "Channel disconnected: \(name)"
    MessageSendFailed(msg) => "Failed to send message: \(msg)"
    MessageParseError(msg) => "Failed to parse message: \(msg)"
    PluginError(msg) => "Plugin error: \(msg)"
    PluginNotFound(name) => "Plugin not found: \(name)"
    PluginLoadFailed(path) => "Failed to load plugin: \(path)"
    PluginInitFailed(name) => "Failed to initialize plugin: \(name)"
    Unknown(msg) => "Unknown error: \(msg)"
    NotImplemented => "Feature not implemented"
    InvalidInput(msg) => "Invalid input: \(msg)"
    OutOfBounds(idx, len) => "Index \(idx) out of bounds (length: \(len))"
  }
}

// 完整错误信息
fn error_to_string(err: Error) -> String {
  "[\(error_code(err))] \(error_message(err))"
}

// 错误严重程度
enum ErrorSeverity {
  Low      // 可忽略
  Medium   // 需要处理
  High     // 需要立即处理
  Critical // 致命错误
}

fn error_severity(err: Error) -> ErrorSeverity {
  match err {
    ConfigNotFound(_) => Medium
    ConfigInvalid(_) => Medium
    ConfigMissingKey(_) => High
    NetworkError(_) => Medium
    HttpError(code, _) => {
      if code >= 500 { High }
      else if code >= 400 { Medium }
      else { Low }
    }
    Timeout(_) => Low
    ConnectionRefused(_) => High
    ApiError(_) => Medium
    AuthError(_) => High
    AuthExpired => Medium
    RateLimitError(_) => Low
    InvalidRequest(_) => Medium
    StorageError(_) => High
    DatabaseError(_) => High
    DatabaseConnectionFailed(_) => Critical
    QueryError(_) => Medium
    ChannelError(_) => Medium
    ChannelNotConnected(_) => Medium
    ChannelDisconnected(_) => Medium
    MessageSendFailed(_) => Medium
    MessageParseError(_) => Low
    PluginError(_) => Medium
    PluginNotFound(_) => Low
    PluginLoadFailed(_) => High
    PluginInitFailed(_) => High
    Unknown(_) => Medium
    NotImplemented => Low
    InvalidInput(_) => Low
    OutOfBounds(_, _) => Medium
  }
}

// 是否可重试
fn is_retryable(err: Error) -> Bool {
  match err {
    NetworkError(_) => true
    Timeout(_) => true
    ConnectionRefused(_) => true
    RateLimitError(_) => true
    HttpError(503, _) => true  // Service Unavailable
    HttpError(502, _) => true  // Bad Gateway
    HttpError(504, _) => true  // Gateway Timeout
    _ => false
  }
}

// Result 类型
type Result[T] = | Ok(T), Err(Error) |

// Result 方法
fn Result::is_ok[T](self: Result[T]) -> Bool {
  match self {
    Ok(_) => true
    Err(_) => false
  }
}

fn Result::is_err[T](self: Result[T]) -> Bool {
  match self {
    Ok(_) => false
    Err(_) => true
  }
}

fn Result::unwrap[T](self: Result[T]) -> T {
  match self {
    Ok(v) => v
    Err(e) => panic("Unwrap failed: \(error_to_string(e))")
  }
}

fn Result::unwrap_or[T](self: Result[T], default: T) -> T {
  match self {
    Ok(v) => v
    Err(_) => default
  }
}

fn Result::unwrap_or_else[T](self: Result[T], f: (Error) -> T) -> T {
  match self {
    Ok(v) => v
    Err(e) => f(e)
  }
}

fn Result::expect[T](self: Result[T], msg: String) -> T {
  match self {
    Ok(v) => v
    Err(e) => panic("\(msg): \(error_to_string(e))")
  }
}

fn Result::map[T, U](self: Result[T], f: (T) -> U) -> Result[U] {
  match self {
    Ok(v) => Ok(f(v))
    Err(e) => Err(e)
  }
}

fn Result::map_err[T](self: Result[T], f: (Error) -> Error) -> Result[T] {
  match self {
    Ok(v) => Ok(v)
    Err(e) => Err(f(e))
  }
}

fn Result::and_then[T, U](self: Result[T], f: (T) -> Result[U]) -> Result[U] {
  match self {
    Ok(v) => f(v)
    Err(e) => Err(e)
  }
}

fn Result::or_else[T](self: Result[T], f: (Error) -> Result[T]) -> Result[T] {
  match self {
    Ok(v) => Ok(v)
    Err(e) => f(e)
  }
}

// 重试配置
struct RetryConfig {
  max_attempts: Int
  initial_delay_ms: Int
  max_delay_ms: Int
  backoff_factor: Double
}

fn RetryConfig::default() -> RetryConfig {
  RetryConfig::{
    max_attempts: 3,
    initial_delay_ms: 100,
    max_delay_ms: 5000,
    backoff_factor: 2.0,
  }
}

// 重试执行
fn retry[T](f: () -> Result[T], config: RetryConfig) -> Result[T] {
  let mut attempts = 0
  let mut delay = config.initial_delay_ms
  
  loop {
    attempts = attempts + 1
    
    match f() {
      Ok(v) => return Ok(v)
      Err(e) => {
        if attempts >= config.max_attempts {
          return Err(e)
        }
        
        if !is_retryable(e) {
          return Err(e)
        }
        
        // 等待
        sleep(delay)
        
        // 指数退避
        delay = min(delay * config.backoff_factor, config.max_delay_ms)
      }
    }
  }
}

// 错误处理器
struct ErrorHandler {
  handlers: Map[String, (Error) -> Unit]
  default_handler: (Error) -> Unit
}

fn ErrorHandler::new() -> ErrorHandler {
  ErrorHandler::{
    handlers: Map::new(),
    default_handler: |e| {
      log_error(error_to_string(e))
      
      match error_severity(e) {
        Critical => panic("Critical error: \(error_to_string(e))")
        _ => {}
      }
    },
  }
}

fn ErrorHandler::on(self: ErrorHandler, code: String, handler: (Error) -> Unit) -> ErrorHandler {
  self.handlers.insert(code, handler)
  self
}

fn ErrorHandler::handle(self: ErrorHandler, err: Error) -> Unit {
  let code = error_code(err)
  
  match self.handlers.get(code) {
    Some(handler) => handler(err)
    None => self.default_handler(err)
  }
}

// 辅助函数
fn min(a: Int, b: Int) -> Int {
  if a < b { a } else { b }
}
