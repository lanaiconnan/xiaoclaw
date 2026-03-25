# XiaoClaw 设计文档

> MoonBit 版 NanoClaw - 轻量级 AI 助手

## 项目概述

**XiaoClaw** 是用 MoonBit 语言实现的轻量级 AI 助手，编译为 WebAssembly 运行。

### 核心优势

| 对比项 | NanoClaw (TypeScript) | XiaoClaw (MoonBit) |
|--------|----------------------|-------------------|
| 运行时 | Node.js (~100MB) | WASM (~5MB) |
| 启动时间 | 秒级 | 毫秒级 |
| 隔离方式 | Docker 容器 | WASM 沙箱 |
| 内存占用 | 高 | 极低 |
| 部署 | 需要运行时 | 单文件 |

---

## 架构设计

### 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                    XiaoClaw WASM                         │
├─────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │ Channels │  │  Agent   │  │ Scheduler│  │  Memory  │ │
│  │  消息通道 │  │  AI引擎  │  │  定时器   │  │   存储   │ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │
├─────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │  Router  │  │   Queue  │  │   IPC    │  │   DB     │ │
│  │   路由    │  │   队列   │  │   通信    │  │  SQLite  │ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘ │
└─────────────────────────────────────────────────────────┘
```

### 模块划分

```
xiaoclaw/
├── src/
│   ├── main.mbt           # 入口
│   ├── config.mbt         # 配置
│   ├── channels/          # 消息通道
│   │   ├── channel.mbt    # Channel trait
│   │   ├── telegram.mbt   # Telegram
│   │   ├── whatsapp.mbt   # WhatsApp
│   │   └── discord.mbt    # Discord
│   ├── agent/             # AI 引擎
│   │   ├── claude.mbt     # Claude API
│   │   ├── context.mbt    # 上下文管理
│   │   └── tools.mbt      # 工具调用
│   ├── scheduler/         # 定时任务
│   │   ├── cron.mbt       # Cron 解析
│   │   └── jobs.mbt       # 任务管理
│   ├── memory/            # 记忆存储
│   │   ├── store.mbt      # 存储接口
│   │   └── sqlite.mbt     # SQLite 实现
│   ├── router/            # 消息路由
│   │   └── router.mbt     # 路由逻辑
│   └── utils/             # 工具函数
│       ├── http.mbt       # HTTP 客户端
│       ├── json.mbt       # JSON 解析
│       └── log.mbt        # 日志
├── moon.mod.json          # MoonBit 模块
├── moon.pkg.json          # 包配置
└── README.md              # 文档
```

---

## 核心模块设计

### 1. Channel (消息通道)

```moonbit
// channels/channel.mbt
trait Channel {
  fn start(self: Self) -> Unit
  fn receive(self: Self) -> Message?
  fn send(self: Self, msg: Message) -> Unit
  fn stop(self: Self) -> Unit
}

struct Message {
  id: String
  from: String
  to: String
  content: String
  timestamp: Int
  channel: String
}
```

### 2. Agent (AI 引擎)

```moonbit
// agent/claude.mbt
struct ClaudeAgent {
  api_key: String
  model: String
  max_tokens: Int
  context: Context
}

fn ClaudeAgent::chat(self: ClaudeAgent, message: String) -> String {
  // 调用 Claude API
  let response = http_post(
    "https://api.anthropic.com/v1/messages",
    self.build_request(message)
  )
  parse_response(response)
}
```

### 3. Scheduler (定时任务)

```moonbit
// scheduler/cron.mbt
struct CronJob {
  id: String
  expression: String
  handler: () -> Unit
  next_run: Int
}

fn CronJob::parse(expr: String) -> CronSchedule {
  // 解析 cron 表达式
  // 支持: * * * * * (分 时 日 月 周)
}
```

### 4. Memory (记忆存储)

```moonbit
// memory/store.mbt
trait MemoryStore {
  fn save(self: Self, key: String, value: String) -> Unit
  fn load(self: Self, key: String) -> String?
  fn delete(self: Self, key: String) -> Unit
  fn list(self: Self, prefix: String) -> Array[String]
}
```

---

## 数据流

```
用户消息
    ↓
Channel.receive()
    ↓
Router.route()
    ↓
Agent.chat()
    ↓
Channel.send()
    ↓
用户收到回复
```

---

## API 设计

### HTTP API (用于 Webhook)

```
POST /webhook/telegram
POST /webhook/whatsapp
POST /webhook/discord

GET  /health
GET  /status
POST /message
```

### CLI 命令

```bash
xiaoclaw start              # 启动服务
xiaoclaw add-channel        # 添加通道
xiaoclaw schedule           # 管理定时任务
xiaoclaw memory             # 管理记忆
```

---

## 配置

```json
{
  "name": "xiaoclaw",
  "version": "0.1.0",
  "channels": {
    "telegram": {
      "token": "xxx",
      "enabled": true
    },
    "whatsapp": {
      "enabled": false
    }
  },
  "agent": {
    "provider": "claude",
    "api_key": "xxx",
    "model": "claude-3-5-sonnet-20241022"
  },
  "memory": {
    "type": "sqlite",
    "path": "data/xiaoclaw.db"
  }
}
```

---

## 性能目标

| 指标 | 目标 |
|------|------|
| WASM 大小 | < 5MB |
| 启动时间 | < 100ms |
| 内存占用 | < 50MB |
| 并发连接 | 100+ |

---

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | MoonBit |
| 编译目标 | WebAssembly |
| 存储 | SQLite (WASM) |
| HTTP | WASI HTTP |
| 序列化 | JSON |

---

## 开发计划

### Phase 1: 核心框架 (Week 1)
- [ ] 项目初始化
- [ ] 基础结构
- [ ] 配置系统
- [ ] 日志系统

### Phase 2: 消息通道 (Week 2)
- [ ] Channel trait
- [ ] Telegram 集成
- [ ] 消息路由

### Phase 3: AI 引擎 (Week 3)
- [ ] Claude API 集成
- [ ] 上下文管理
- [ ] 工具调用

### Phase 4: 定时任务 (Week 4)
- [ ] Cron 解析
- [ ] 任务调度
- [ ] 持久化

### Phase 5: 记忆存储 (Week 5)
- [ ] SQLite 集成
- [ ] 记忆管理
- [ ] 搜索功能

### Phase 6: 部署优化 (Week 6)
- [ ] WASM 优化
- [ ] 文档完善
- [ ] 测试覆盖

---

*设计完成时间: 2026-03-24*
*深海团队出品*
---

## v2.0 新功能设计

### 新功能优先级

| 优先级 | 功能 | 理由 |
|--------|------|------|
| P0 | CLI 命令行 | 提升可用性 |
| P0 | 错误处理 | 提升稳定性 |
| P1 | 日志系统 | 提升可观测性 |
| P1 | Discord 通道 | 扩大用户群 |
| P2 | WhatsApp 通道 | 扩大用户群 |
| P2 | 配置热更新 | 提升运维体验 |
| P3 | Plugin 系统 | 提升扩展性 |

### CLI 设计

```bash
# 启动服务
xiaoclaw start

# 添加定时任务
xiaoclaw schedule add "0 9 * * *" "Send daily summary"

# 查看状态
xiaoclaw status

# 配置管理
xiaoclaw config set TELEGRAM_TOKEN xxx
xiaoclaw config get TELEGRAM_TOKEN

# 日志查看
xiaoclaw logs --tail 100
```

### 错误处理设计

```moonbit
// Result 类型错误处理
fn handle_error(result: Result[String, Error]) -> String {
  match result {
    Ok(value) => value,
    Err(e) => {
      log_error("Error: \(e.message)")
      "An error occurred"
    }
  }
}
```

### 日志系统设计

```moonbit
// 日志级别
enum LogLevel {
  Debug
  Info
  Warn
  Error
}

// 日志输出
struct Logger {
  level: LogLevel
  outputs: Array[LogOutput]
}

trait LogOutput {
  fn write(self: Self, msg: String) -> Unit
}

// 输出目标
struct ConsoleOutput
struct FileOutput { path: String }
struct RemoteOutput { url: String }
```

### Discord 通道设计

```moonbit
struct DiscordChannel {
  token: String
  intents: Int
  base_url: String
}

// Discord Intent flags
const GUILD_MESSAGES = 1 << 9
const MESSAGE_CONTENT = 1 << 15
```

---

## CLI 设计

### 命令结构

```
xiaoclaw <command> [subcommand] [options]
```

### 子命令

| 命令 | 描述 |
|------|------|
| `start` | 启动服务 |
| `stop` | 停止服务 |
| `status` | 查看状态 |
| `config` | 配置管理 |
| `schedule` | 定时任务 |
| `logs` | 日志查看 |
| `plugin` | 插件管理 |
| `test` | 测试运行 |
| `benchmark` | 性能测试 |

### 输出格式

支持 `--json` 选项输出 JSON 格式，便于脚本集成。

---

## 测试设计

### 测试框架

- TestRunner: 测试运行器
- TestSuite: 测试套件
- TestResult: 测试结果

### 断言函数

- assert_true / assert_false
- assert_eq / assert_ne
- assert_contains / assert_starts_with
- assert_len

### 测试套件

- Config: 配置模块测试
- Context: 上下文测试
- Memory: 存储测试
- Scheduler: 调度器测试
- Error: 错误处理测试
- Plugin: 插件系统测试

### 覆盖率目标

- 行覆盖: 80%
- 分支覆盖: 75%
