// XiaoClaw 配置模块

struct Config {
  name: String
  version: String
  channels: ChannelConfig
  agent: AgentConfig
  memory: MemoryConfig
}

struct ChannelConfig {
  telegram: TelegramConfig
  whatsapp: WhatsAppConfig
  discord: DiscordConfig
}

struct TelegramConfig {
  token: String
  enabled: Bool
}

struct WhatsAppConfig {
  enabled: Bool
}

struct DiscordConfig {
  token: String
  enabled: Bool
}

struct AgentConfig {
  provider: String
  api_key: String
  model: String
  max_tokens: Int
}

struct MemoryConfig {
  type: String
  path: String
}

fn Config::load() -> Config {
  // 从环境变量或配置文件加载
  Config::{
    name: "XiaoClaw",
    version: "0.1.0",
    channels: ChannelConfig::{
      telegram: TelegramConfig::{
        token: env("TELEGRAM_TOKEN", ""),
        enabled: env("TELEGRAM_ENABLED", "false") == "true",
      },
      whatsapp: WhatsAppConfig::{
        enabled: false,
      },
      discord: DiscordConfig::{
        token: env("DISCORD_TOKEN", ""),
        enabled: env("DISCORD_ENABLED", "false") == "true",
      },
    },
    agent: AgentConfig::{
      provider: "claude",
      api_key: env("ANTHROPIC_API_KEY", ""),
      model: env("MODEL", "claude-3-5-sonnet-20241022"),
      max_tokens: 4096,
    },
    memory: MemoryConfig::{
      type: "sqlite",
      path: "data/xiaoclaw.db",
    },
  }
}

fn Config::to_json(self: Config) -> String {
  // 序列化为 JSON
  json_encode(self)
}

fn env(key: String, default: String) -> String {
  // 获取环境变量
  // WASI 环境变量读取
  match get_env(key) {
    Some(value) => value,
    None => default,
  }
}