# XiaoClaw

> 🦞 **Lightweight AI Assistant** - MoonBit + WebAssembly
> **Smallest Size (<5MB) | Fastest Startup (<100ms) | Lowest Resource Usage**

## ✨ Key Advantages

| Feature | XiaoClaw | Others |
|---------|----------|--------|
| **Size** | **< 5MB** | 30MB - 200MB+ |
| **Startup** | **< 100ms** | 1s - 10s |
| **Memory** | **< 50MB** | 100MB - 500MB+ |

## 🚀 Performance Comparison

```
Size Comparison:
XiaoClaw      ██                        5MB
LangChain     ████████████████████████  100MB
Claude Code   ████████████████████████████████████  200MB+

Startup Time Comparison:
XiaoClaw      ◄ 100ms
Node.js       ◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄  1-3s
Claude Code   ◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄◄  5-10s
```

## 📦 Features

| Feature | Description |
|---------|-------------|
| **Lightweight** | WASM < 5MB, Memory < 50MB |
| **Fast** | Startup time < 100ms |
| **Secure** | WASM sandbox isolation |
| **Cross-platform** | Any WASM-compatible environment |
| **AI-powered** | Support Claude / OpenAI |

## 📡 Message Channels

```
✅ Telegram Bot
✅ Discord Bot
✅ Feishu (Lark)
✅ WhatsApp
❌ Slack (Coming soon)
```

## 🧩 Plugin System

```
✅ Health Check Plugin
✅ Echo Plugin
✅ Timer Plugin
❌ More plugins (Contribute!)
```

## 🧪 Test Coverage

```
✅ Config
✅ Context
✅ Memory
✅ Scheduler
✅ Cron
✅ Error
✅ Plugin
```

## 🚀 Quick Start

### Installation

```bash
# Install MoonBit
curl -fsSL https://www.moonbitlang.com/install.sh | bash

# Clone project
git clone https://github.com/lanaiconnan/xiaoclaw.git
cd xiaoclaw

# Build
moon build

# Run tests
moon test

# Run
moon run
```

### Configuration

Create `.env` file:

```bash
ANTHROPIC_API_KEY=your_api_key
TELEGRAM_TOKEN=your_telegram_token
TELEGRAM_ENABLED=true
FEISHU_APP_ID=your_app_id
FEISHU_APP_SECRET=your_app_secret
WHATSAPP_API_KEY=your_whatsapp_key
WHATSAPP_ENABLED=true
```

### Usage

```bash
# Start service
xiaoclaw start

# Check status
xiaoclaw status

# Manage scheduled tasks
xiaoclaw schedule add "0 9 * * *" "Send daily summary"

# View logs
xiaoclaw logs
```

## 📁 Project Structure

```
xiaoclaw/
├── src/
│   ├── main.mbt
│   ├── config.mbt
│   ├── channels/
│   │   ├── channel.mbt
│   │   ├── telegram.mbt
│   │   ├── discord.mbt
│   │   ├── feishu.mbt
│   │   └── whatsapp.mbt
│   ├── agent/
│   │   └── claude.mbt
│   ├── scheduler/
│   │   └── cron.mbt
│   ├── memory/
│   │   └── store.mbt
│   ├── error/
│   │   └── error.mbt
│   ├── plugin/
│   │   └── plugin.mbt
│   ├── test/
│   │   └── test_framework.mbt
│   ├── benchmark/
│   │   └── benchmark.mbt
│   ├── optimize/
│   │   └── lazy.mbt
│   ├── cli/
│   │   └── cli.mbt
│   ├── log/
│   │   └── logger.mbt
│   └── utils/
│       └── utils.mbt
├── tests/
│   └── unit_tests.mbt
├── docs/
│   ├── CLI.md
│   └── TEST.md
├── moon.mod.json
└── README.md
```

## 📊 Performance Targets

| Metric | Target | Status |
|--------|--------|--------|
| WASM Size | < 5MB | ✅ |
| Startup Time | < 100ms | ✅ |
| Memory Usage | < 50MB | ✅ |
| Cold Start | < 100ms | ✅ |
| Warm Start | < 10ms | ✅ |

## 🛠️ Development

```bash
# Run tests
moon test

# Build WASM
moon build --target wasm

# Performance test
moon run --benchmark
```

## 🤝 Contributing

Issues and Pull Requests are welcome!

## 📄 License

MIT License

---

**Made by Deep Sea Team** 🦞
