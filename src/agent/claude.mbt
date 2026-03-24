// AI Agent 模块

struct Agent {
  provider: String
  api_key: String
  model: String
  max_tokens: Int
  system_prompt: String
}

struct Context {
  messages: Array[ContextMessage]
  max_length: Int
}

struct ContextMessage {
  role: String  // "user" | "assistant"
  content: String
  timestamp: Int
}

fn Agent::new(config: AgentConfig) -> Agent {
  Agent::{
    provider: config.provider,
    api_key: config.api_key,
    model: config.model,
    max_tokens: config.max_tokens,
    system_prompt: "You are XiaoClaw, a helpful AI assistant.",
  }
}

fn Agent::chat(self: Agent, message: String, context: Context) -> String {
  // 构建请求
  let messages = self.build_messages(message, context)
  
  // 调用 API
  match self.provider {
    "claude" => self.call_claude(messages),
    "openai" => self.call_openai(messages),
    _ => "Error: Unknown provider",
  }
}

fn Agent::call_claude(self: Agent, messages: Array[Map]) -> String {
  let url = "https://api.anthropic.com/v1/messages"
  let body = {
    "model": self.model,
    "max_tokens": self.max_tokens,
    "system": self.system_prompt,
    "messages": messages,
  }
  
  let headers = [
    ("Content-Type", "application/json"),
    ("x-api-key", self.api_key),
    ("anthropic-version", "2023-06-01"),
  ]
  
  let response = http_post_with_headers(url, json_encode(body), headers)
  
  match json_decode(response) {
    Some(data) => {
      match data["content"] {
        Some(content) => content[0]["text"],
        None => "Error: No response",
      }
    }
    None => "Error: Failed to parse response",
  }
}

fn Agent::call_openai(self: Agent, messages: Array[Map]) -> String {
  let url = "https://api.openai.com/v1/chat/completions"
  let body = {
    "model": self.model,
    "messages": messages,
    "max_tokens": self.max_tokens,
  }
  
  let headers = [
    ("Content-Type", "application/json"),
    ("Authorization", "Bearer \(self.api_key)"),
  ]
  
  let response = http_post_with_headers(url, json_encode(body), headers)
  
  match json_decode(response) {
    Some(data) => {
      match data["choices"] {
        Some(choices) => choices[0]["message"]["content"],
        None => "Error: No response",
      }
    }
    None => "Error: Failed to parse response",
  }
}

fn Agent::build_messages(self: Agent, message: String, context: Context) -> Array[Map] {
  let mut messages = []
  
  // 添加上下文消息
  for ctx_msg in context.messages {
    messages.push({
      "role": ctx_msg.role,
      "content": ctx_msg.content,
    })
  }
  
  // 添加当前消息
  messages.push({
    "role": "user",
    "content": message,
  })
  
  messages
}

// Context 管理
fn Context::new(max_length: Int) -> Context {
  Context::{
    messages: [],
    max_length: max_length,
  }
}

fn Context::append(self: Context, role: String, content: String) -> Context {
  let mut new_messages = self.messages.clone()
  
  new_messages.push(ContextMessage::{
    role: role,
    content: content,
    timestamp: now(),
  })
  
  // 限制长度
  if new_messages.length() > self.max_length {
    new_messages = new_messages.drop(1)
  }
  
  Context::{
    messages: new_messages,
    max_length: self.max_length,
  }
}

fn Context::to_summary(self: Context) -> String {
  // 生成上下文摘要
  let mut summary = "Context (\(self.messages.length()) messages):\n"
  for msg in self.messages {
    summary = "\(summary)- \(msg.role): \(msg.content.take(50))...\n"
  }
  summary
}