// 工具函数

// HTTP 客户端
fn http_get(url: String) -> String {
  // WASI HTTP GET
  wasi_http_get(url)
}

fn http_post(url: String, body: String) -> String {
  // WASI HTTP POST
  wasi_http_post(url, body)
}

fn http_post_with_headers(url: String, body: String, headers: Array[(String, String)]) -> String {
  // WASI HTTP POST with headers
  wasi_http_post_with_headers(url, body, headers)
}

// JSON
fn json_encode(value: Any) -> String {
  // JSON 序列化
  internal_json_encode(value)
}

fn json_decode(s: String) -> Any? {
  // JSON 解析
  internal_json_decode(s)
}

// 日志
fn log_info(msg: String) -> Unit {
  let timestamp = format_time(now())
  println("[INFO] \(timestamp) - \(msg)")
}

fn log_error(msg: String) -> Unit {
  let timestamp = format_time(now())
  println("[ERROR] \(timestamp) - \(msg)")
}

fn log_debug(msg: String) -> Unit {
  if DEBUG_MODE {
    let timestamp = format_time(now())
    println("[DEBUG] \(timestamp) - \(msg)")
  }
}

// 时间
fn now() -> Int {
  // 获取当前时间戳（秒）
  wasi_time_now()
}

fn format_time(timestamp: Int) -> String {
  // 格式化时间
  let date = timestamp_to_date(timestamp)
  "\(date.year)-\(pad(date.month))-\(pad(date.day)) \(pad(date.hour)):\(pad(date.minute)):\(pad(date.second))"
}

fn sleep(ms: Int) -> Unit {
  // 休眠
  wasi_sleep(ms)
}

// 字符串工具
fn parse_int(s: String) -> Int {
  // 解析整数
  internal_parse_int(s)
}

fn pad(n: Int) -> String {
  if n < 10 {
    "0\(n)"
  } else {
    "\(n)"
  }
}

// 环境变量
fn get_env(key: String) -> String? {
  // WASI 环境变量
  wasi_get_env(key)
}

// SQLite
fn sqlite_open(path: String) -> SQLiteConnection {
  internal_sqlite_open(path)
}

fn sqlite_exec(db: SQLiteConnection, sql: String) -> Unit {
  internal_sqlite_exec(db, sql)
}

fn sqlite_exec_params(db: SQLiteConnection, sql: String, params: Array[String]) -> Unit {
  internal_sqlite_exec_params(db, sql, params)
}

fn sqlite_query(db: SQLiteConnection, sql: String, params: Array[String]) -> Map? {
  internal_sqlite_query(db, sql, params)
}

fn sqlite_query_all(db: SQLiteConnection, sql: String, params: Array[String]) -> Array[Map] {
  internal_sqlite_query_all(db, sql, params)
}

// 并发
fn spawn(f: () -> Unit) -> Unit {
  // 创建新线程
  internal_spawn(f)
}

// Map 工具
struct Map[K, V] {
  data: Array[(K, V)]
}

fn Map::new[K, V]() -> Map[K, V] {
  Map::{ data: [] }
}

fn Map::insert[K, V](self: Map[K, V], key: K, value: V) -> Unit {
  // 插入或更新
  self.data = self.data.filter(|(k, _)| k != key)
  self.data.push((key, value))
}

fn Map::get[K, V](self: Map[K, V], key: K) -> V? {
  for (k, v) in self.data {
    if k == key {
      return Some(v)
    }
  }
  None
}

fn Map::remove[K, V](self: Map[K, V], key: K) -> Unit {
  self.data = self.data.filter(|(k, _)| k != key)
}

fn Map::keys[K, V](self: Map[K, V]) -> Array[K] {
  self.data.map(|(k, _)| k)
}