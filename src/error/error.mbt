// XiaoClaw 错误处理模块

// 错误类型
enum Error {
  // 配置错误
  ConfigNotFound(String)
  ConfigInvalid(String)
  
  // 网络错误
  NetworkError(String)
  HttpError(Int, String)
  Timeout
  
  // API 错误
  ApiError(String)
  AuthError(String)
  RateLimitError(Int)
  
  // 存储错误
  StorageError(String)
  DatabaseError(String)
  
  // 通道错误
  ChannelError(String)
  ChannelNotConnected(String)
  
  // 通用错误
  Unknown(String)
  NotImplemented
}

// 错误信息
fn error_to_string(err: Error) -> String {
  match err {
    ConfigNotFound(key) => "Config not found: \(key)"
    ConfigInvalid(msg) => "Config invalid: \(msg)"
    NetworkError(msg) => "Network error: \(msg)"
    HttpError(code, msg) => "HTTP error \(code): \(msg)"
    Timeout => "Request timeout"
    ApiError(msg) => "API error: \(msg)"
    AuthError(msg) => "Auth error: \(msg)"
    RateLimitError(retry) => "Rate limited, retry after \(retry) seconds"
    StorageError(msg) => "Storage error: \(msg)"
    DatabaseError(msg) => "Database error: \(msg)"
    ChannelError(msg) => "Channel error: \(msg)"
    ChannelNotConnected(name) => "Channel not connected: \(name)"
    Unknown(msg) => "Unknown error: \(msg)"
    NotImplemented => "Not implemented"
  }
}

// Result 类型
type Result[T] = | Ok(T), Err(Error) |

// 错误处理方法
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

// 重试装饰器
fn retry[T](f: () -> Result[T], max_attempts: Int, delay_ms: Int) -> Result[T] {
  let mut attempts = 0
  
  loop {
    attempts = attempts + 1
    
    match f() {
      Ok(v) => return Ok(v)
      Err(e) => {
        if attempts >= max_attempts {
          return Err(e)
        }
        
        // 检查是否是可重试的错误
        match e {
          NetworkError(_) | Timeout | RateLimitError(_) => {
            sleep(delay_ms)
          }
          _ => return Err(e)
        }
      }
    }
  }
}

// 错误恢复
fn recover[T](f: () -> Result[T], fallback: () -> T) -> T {
  match f() {
    Ok(v) => v
    Err(e) => {
      log_error("Recovered from error: \(error_to_string(e))")
      fallback()
    }
  }
}

// 全局错误处理器
struct ErrorHandler {
  handlers: Map[Error, (Error) -> Unit]
}

fn ErrorHandler::new() -> ErrorHandler {
  ErrorHandler::{
    handlers: Map::new(),
  }
}

fn ErrorHandler::register(self: ErrorHandler, err_type: Error, handler: (Error) -> Unit) -> Unit {
  // 简化实现
  log_info("Error handler registered")
}

fn ErrorHandler::handle(self: ErrorHandler, err: Error) -> Unit {
  log_error("Error occurred: \(error_to_string(err))")
  
  // 调用注册的处理器
  match self.handlers.get(err) {
    Some(handler) => handler(err)
    None => {
      // 默认处理
      match err {
        Fatal => panic("Fatal error")
        _ => {}
      }
    }
  }
}
