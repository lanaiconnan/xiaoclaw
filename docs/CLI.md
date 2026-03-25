# XiaoClaw CLI 使用指南

## 概述

XiaoClaw 提供完整的命令行界面，支持服务管理、配置管理、定时任务、日志查看等功能。

## 快速开始

```bash
# 查看帮助
xiaoclaw help

# 查看版本
xiaoclaw version

# 启动服务
xiaoclaw start

# 查看状态
xiaoclaw status
```

## 命令分类

### 🏃 运行命令

| 命令 | 别名 | 描述 |
|------|------|------|
| `start` | `s` | 启动 XiaoClaw 服务 |
| `stop` | - | 停止 XiaoClaw 服务 |
| `restart` | `reload` | 重启 XiaoClaw 服务 |
| `status` | `stat` | 查看服务状态 |

### ⚙️ 配置命令

| 命令 | 描述 |
|------|------|
| `config get <key>` | 获取配置项 |
| `config set <key> <value>` | 设置配置项 |
| `config list` | 列出所有配置 |
| `config delete <key>` | 删除配置项 |

示例:
```bash
# 获取 Telegram Token
xiaoclaw config get TELEGRAM_TOKEN

# 设置 API Key
xiaoclaw config set ANTHROPIC_API_KEY sk-xxx

# 列出所有配置
xiaoclaw config list
```

### 📅 定时任务命令

| 命令 | 描述 |
|------|------|
| `schedule add <cron> <name>` | 添加定时任务 |
| `schedule list` | 列出所有任务 |
| `schedule remove <id>` | 删除任务 |
| `schedule enable <id>` | 启用任务 |
| `schedule disable <id>` | 禁用任务 |

### 📝 日志命令

| 命令 | 描述 |
|------|------|
| `logs show` | 查看日志 |
| `logs clear` | 清除日志 |
| `logs export <file>` | 导出日志 |

### 🔌 插件命令

| 命令 | 描述 |
|------|------|
| `plugin list` | 列出所有插件 |
| `plugin enable <name>` | 启用插件 |
| `plugin disable <name>` | 禁用插件 |
| `plugin install <path>` | 安装插件 |

### 🧪 测试命令

| 命令 | 描述 |
|------|------|
| `test run` | 运行所有测试 |
| `test list` | 列出测试用例 |
| `test coverage` | 查看测试覆盖率 |

## 全局选项

| 选项 | 描述 |
|------|------|
| `--verbose` | 详细输出 |
| `--quiet` | 静默模式 |
| `--json` | JSON 格式输出 |

## 输出格式

### 文本格式 (默认)
```
📊 XiaoClaw 服务状态
─────────────────────────
版本:        v0.3.2
状态:        ✅ 运行中
```

### JSON 格式
```bash
xiaoclaw status --json
```

```json
{
  "version": "0.3.2",
  "status": "running",
  "uptime": 9240
}
```

---

**XiaoClaw CLI - 让管理更简单** 🦞
