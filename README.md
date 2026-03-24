# XiaoClaw

> 🦀 轻量级 AI 助手 - MoonBit + WebAssembly

**XiaoClaw** 是用 MoonBit 语言实现的轻量级 AI 助手，编译为 WebAssembly 运行。

## ✨ 特性

| 特性 | 描述 |
|------|------|
| **轻量** | WASM < 5MB，内存 < 50MB |
| **快速** | 启动时间 < 100ms |
| **安全** | WASM 沙箱天然隔离 |
| **跨平台** | 任何支持 WASM 的环境 |
| **AI 驱动** | 支持 Claude / OpenAI |

## 🆚 对比

| 对比项 | NanoClaw (TypeScript) | XiaoClaw (MoonBit) |
|--------|----------------------|-------------------|
| 运行时 | Node.js (~100MB) | WASM (~5MB) |
| 启动时间 | 秒级 | 毫秒级 |
| 隔离方式 | Docker 容器 | WASM 沙箱 |
| 内存占用 | 高 | 极低 |
| 部署 | 需要运行时 | 单文件 |

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

# 运行
moon run
```

### 配置

创建 `.env` 文件：

```bash
ANTHROPIC_API_KEY=your_api_key
TELEGRAM_TOKEN=your_telegram_token
TELEGRAM_ENABLED=true
```

### 使用

```bash
# 启动服务
xiaoclaw start

# 添加定时任务
xiaoclaw schedule add "0 9 * * *" "Send daily summary"

# 查看状态
xiaoclaw status
```

## 📦 项目结构

```
xiaoclaw/
├── src/
│   ├── main.mbt           # 入口
│   ├── config.mbt         # 配置
│   ├── channels/          # 消息通道
│   │   ├── channel.mbt    # Channel trait
│   │   └── telegram.mbt   # Telegram
│   ├── agent/             # AI 引擎
│   │   └── claude.mbt     # Claude API
│   ├── scheduler/         # 定时任务
│   │   └── cron.mbt       # Cron 解析
│   ├── memory/            # 记忆存储
│   │   └── store.mbt      # SQLite
│   └── utils/             # 工具函数
├── tests/                 # 测试
├── moon.mod.json          # MoonBit 模块
└── README.md              # 文档
```

## 🔧 配置

```json
{
  "name": "xiaoclaw",
  "channels": {
    "telegram": {
      "token": "xxx",
      "enabled": true
    }
  },
  "agent": {
    "provider": "claude",
    "api_key": "xxx",
    "model": "claude-3-5-sonnet-20241022"
  }
}
```

## 📝 使用示例

在 Telegram 中发送消息：

```
@XiaoClaw 帮我总结今天的工作
@XiaoClaw 每天早上9点发送新闻摘要
@XiaoClaw 记住我的偏好设置
```

## 🛠️ 开发

```bash
# 运行测试
moon test

# 构建 WASM
moon build --target wasm

# 构建 WASM-GC
moon build --target wasm-gc
```

## 📊 性能

| 指标 | 目标 | 实测 |
|------|------|------|
| WASM 大小 | < 5MB | - |
| 启动时间 | < 100ms | - |
| 内存占用 | < 50MB | - |

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

---

**深海团队出品** 🦞