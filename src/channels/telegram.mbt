// Telegram Channel 实现

struct TelegramChannel {
  token: String
  base_url: String
  offset: Int
  enabled: Bool
}

fn TelegramChannel::new(token: String) -> TelegramChannel {
  TelegramChannel::{
    token: token,
    base_url: "https://api.telegram.org/bot\(token)",
    offset: 0,
    enabled: true,
  }
}

impl Channel for TelegramChannel {
  fn start(self: Self) -> Unit {
    log_info("Telegram channel starting...")
    self.enabled = true
  }

  fn receive(self: Self) -> Message? {
    if !self.enabled {
      return None
    }
    
    // 获取更新
    let url = "\(self.base_url)/getUpdates?offset=\(self.offset)&timeout=30"
    let response = http_get(url)
    
    match parse_updates(response) {
      Some(updates) => {
        if updates.length() > 0 {
          let update = updates[0]
          self.offset = update.update_id + 1
          Some(update_to_message(update))
        } else {
          None
        }
      }
      None => None,
    }
  }

  fn send(self: Self, msg: Response) -> Unit {
    let url = "\(self.base_url)/sendMessage"
    let body = {
      "chat_id": msg.to,
      "text": msg.content,
    }
    http_post(url, json_encode(body))
  }

  fn stop(self: Self) -> Unit {
    self.enabled = false
    log_info("Telegram channel stopped")
  }

  fn name(self: Self) -> String {
    "telegram"
  }
}

// Telegram 更新结构
struct TelegramUpdate {
  update_id: Int
  message: TelegramMessage
}

struct TelegramMessage {
  message_id: Int
  from: TelegramUser
  chat: TelegramChat
  text: String
}

struct TelegramUser {
  id: Int
  first_name: String
  username: String
}

struct TelegramChat {
  id: Int
  type: String
}

fn update_to_message(update: TelegramUpdate) -> Message {
  Message::{
    id: "\(update.message.message_id)",
    from: "\(update.message.chat.id)",
    to: "\(update.message.from.id)",
    content: update.message.text,
    timestamp: now(),
    channel: "telegram",
  }
}

fn parse_updates(response: String) -> Array[TelegramUpdate]? {
  // 解析 Telegram API 响应
  match json_decode(response) {
    Some(data) => {
      match data["result"] {
        Some(results) => results,
        None => None,
      }
    }
    None => None,
  }
}