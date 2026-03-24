// 记忆存储模块

trait MemoryStore {
  fn save(self: Self, key: String, value: String) -> Unit
  fn load(self: Self, key: String) -> String?
  fn delete(self: Self, key: String) -> Unit
  fn list(self: Self, prefix: String) -> Array[String]
  fn save_context(self: Self, user: String, context: Context) -> Unit
  fn load_context(self: Self, user: String) -> Context
}

// SQLite 实现
struct SQLiteStore {
  path: String
  db: SQLiteConnection
}

fn SQLiteStore::new(path: String) -> SQLiteStore {
  let db = sqlite_open(path)
  
  // 创建表
  sqlite_exec(db, "
    CREATE TABLE IF NOT EXISTS memory (
      key TEXT PRIMARY KEY,
      value TEXT,
      created_at INTEGER,
      updated_at INTEGER
    )
  ")
  
  sqlite_exec(db, "
    CREATE TABLE IF NOT EXISTS context (
      user TEXT PRIMARY KEY,
      messages TEXT,
      updated_at INTEGER
    )
  ")
  
  SQLiteStore::{
    path: path,
    db: db,
  }
}

impl MemoryStore for SQLiteStore {
  fn save(self: Self, key: String, value: String) -> Unit {
    let now = now()
    sqlite_exec(self.db, "
      INSERT OR REPLACE INTO memory (key, value, created_at, updated_at)
      VALUES (?, ?, ?, ?)
    ", [key, value, now, now])
  }

  fn load(self: Self, key: String) -> String? {
    let result = sqlite_query(self.db, "
      SELECT value FROM memory WHERE key = ?
    ", [key])
    
    match result {
      Some(row) => row["value"],
      None => None,
    }
  }

  fn delete(self: Self, key: String) -> Unit {
    sqlite_exec(self.db, "
      DELETE FROM memory WHERE key = ?
    ", [key])
  }

  fn list(self: Self, prefix: String) -> Array[String] {
    let result = sqlite_query_all(self.db, "
      SELECT key FROM memory WHERE key LIKE ? || '%'
    ", [prefix])
    
    result.map(|row| row["key"])
  }

  fn save_context(self: Self, user: String, context: Context) -> Unit {
    let messages_json = json_encode(context.messages)
    let now = now()
    
    sqlite_exec(self.db, "
      INSERT OR REPLACE INTO context (user, messages, updated_at)
      VALUES (?, ?, ?)
    ", [user, messages_json, now])
  }

  fn load_context(self: Self, user: String) -> Context {
    let result = sqlite_query(self.db, "
      SELECT messages FROM context WHERE user = ?
    ", [user])
    
    match result {
      Some(row) => {
        let messages = json_decode(row["messages"])
        Context::{
          messages: messages,
          max_length: 100,
        }
      }
      None => Context::new(100),
    }
  }
}

// 内存存储实现（用于测试）
struct InMemoryStore {
  data: Map[String, String]
  contexts: Map[String, Context]
}

fn InMemoryStore::new() -> InMemoryStore {
  InMemoryStore::{
    data: Map::new(),
    contexts: Map::new(),
  }
}

impl MemoryStore for InMemoryStore {
  fn save(self: Self, key: String, value: String) -> Unit {
    self.data.insert(key, value)
  }

  fn load(self: Self, key: String) -> String? {
    self.data.get(key)
  }

  fn delete(self: Self, key: String) -> Unit {
    self.data.remove(key)
  }

  fn list(self: Self, prefix: String) -> Array[String] {
    self.data.keys().filter(|k| k.starts_with(prefix))
  }

  fn save_context(self: Self, user: String, context: Context) -> Unit {
    self.contexts.insert(user, context)
  }

  fn load_context(self: Self, user: String) -> Context {
    match self.contexts.get(user) {
      Some(ctx) => ctx,
      None => Context::new(100),
    }
  }
}