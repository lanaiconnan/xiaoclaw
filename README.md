# XiaoClaw

> 🦞 轻量级 AI 助手 - MoonBit + WebAssembly
> **体积最小 (<5MB) | 启动最快 (<100ms) | 资源占用最低**

## ✨ 核心优势

| 特性 | XiaoClaw | 其他方案 |
|------|----------|----------|
| **体积** | **< 5MB** | 30MB - 200MB+ |
| **启动** | **< 100ms** | 1s - 10s |
| **内存** | **< 50MB** | 100MB - 500MB+ |

## 🚀 性能对比

```
体积对比:
XiaoClaw      ██                        5MB
LangChain     ████████████████████████  100MB
Claude Code   ████████████████████████████████████  200MB+

启动时间对比:
XiaoClaw      ◄ 100ms
Node.js       ◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄  1-3s
Claude Code   ◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄  5-10s
```

## 📦 特性

| 特性 | 描述 |
|------|------|
| **轻量** | WASM < 5MB，内存 < 50MB |
| **快速** | 启动时间 < 100ms |
| **安全** | WASM 沙箱天然隔离 |
| **跨平台** | 任何支持 WASM 的环境 |
| **AI 驱动** | 支持 Claude / OpenAI |

## 📡 消息通道

```
✅ Telegram Bot
✅ Discord Bot
✅ 飞书 (Feishu/Lark)
❌ WhatsApp (待实现)
```

## 🧩 插件系统

```
✅ 健康检查插件
✅ Echo 插件
✅ 定时器插件
❌ 更多插件 (贡献代码！)
```

## 🧪 测试覆盖

```
✅ Config
✅ Context
✅ Memory
✅ Scheduler
✅ Cron
✅ Error
✅ Plugin
```

## 🚀 快速开始

### 安装

```bash
# 安装 MoonBit
curl -fsSL https://www.moonbitlang.com/install.sh | bash

# 克隆项目
git clone https://github.com/lanaiconnan/xiaoclaw.git
cd xiaoclaw

# 构建
moon build

# 运行测试
moon test

# 运行
moon run
```

### 配置

创建 `.env` 文件：

```bash
ANTHROPIC_API_KEY=your_api_key
TELEGRAM_TOKEN=your_telegram_token
TELEGRAM_ENABLED=true
FEISHU_APP_ID=your_app_id
FEISHU_APP_SECRET=your_app_secret
```

### 使用

```bash
# 启动服务
xiaoclaw start

# 查看状态
xiaoclaw status

# 管理定时任务
xiaoclaw schedule add "0 9 * * *" "Send daily summary"

# 查看日志
xiaoclaw logs
```

## 📁 项目结构

```
xiaoclaw/
├── src/
│   ├── main.mbt           # 入口
│   ├── config.mbt         # 配置
│   ├── channels/          # 消息通道
│   │   ├── channel.mbt    # Channel trait
│   │   ├── telegram.mbt   # Telegram
│   │   ├── discord.mbt    # Discord
│   │   └── feishu.mbt     # Feishu
│   ├── agent/             # AI 引擎
│   │   └── claude.mbt     # Claude API
│   ├── scheduler/         # 定时任务
│   │   └── cron.mbt       # Cron 解析
│   ├── memory/            # 记忆存储
│   │   └── store.mbt      # SQLite
│   ├── error/             # 错误处理
│   │   └── error.mbt
│   ├── plugin/            # 插件系统
│   │   └── plugin.mbt
│   ├── test/              # 测试框架
│   │   └── test_framework.mbt
│   ├── benchmark/          # 性能基准
│   │   └── benchmark.mbt
│   ├── optimize/          # 优化工具
│   │   └── lazy.mbt
│   ├── cli/               # 命令行
│   │   └── cli.mbt
│   ├── log/               # 日志
│   │   └── logger.mbt
│   └── utils/             # 工具函数
│       └── utils.mbt
├── tests/                 # 测试
│   └── unit_tests.mbt
├── docs/                  # 文档
│   ├── BENCHMARK.md       # 性能对比
│   ├── COMPARE.md         # 方案对比
│   └── DESIGN.md          # 设计文档
├── moon.mod.json
└── README.md
```

## 📊 性能目标

| 指标 | 目标 | 状态 |
|------|------|------|
| WASM 体积 | < 5MB | ✅ |
| 启动时间 | < 100ms | ✅ |
| 内存占用 | < 50MB | ✅ |
| 冷启动 | < 100ms | ✅ |
| 热启动 | < 10ms | ✅ |

## 🛠️ 开发

```bash
# 运行测试
moon test

# 构建 WASM
moon build --target wasm

# 性能测试
moon run --benchmark
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

---

**深海团队出品** 🦞
