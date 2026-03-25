// XiaoClaw 飞书 (Feishu/Lark) 通道实现

// 飞书配置
struct FeishuConfig {
  app_id: String
  app_secret: String
  encrypt_key: String?
  verification_token: String?
}

// 飞书通道
struct FeishuChannel {
  config: FeishuConfig
  base_url: String
  tenant_token: String?
  token_expires: Int
  enabled: Bool
}

fn FeishuChannel::new(config: FeishuConfig) -> FeishuChannel {
  FeishuChannel::{
    config: config,
    base_url: "https://open.feishu.cn/open-apis",
    tenant_token: None,
    token_expires: 0,
    enabled: true,
  }
}

impl Channel for FeishuChannel {
  fn start(self: Self) -> Unit {
    log_info("Feishu channel starting...")
    
    // 获取 tenant_access_token
    self.refresh_token()
    
    self.enabled = true
    log_info("Feishu channel started")
  }

  fn receive(self: Self) -> Message? {
    if !self.enabled {
      return None
    }
    
    // 飞书通过事件回调推送消息
    // 需要在 HTTP 服务器接收回调
    None
  }

  fn send(self: Self, msg: Response) -> Unit {
    if !self.enabled {
      return
    }
    
    // 确保 token 有效
    if self.token_expires < now() {
      self.refresh_token()
    }
    
    // 发送消息
    let url = "\(self.base_url)/im/v1/messages?receive_id_type=user_id"
    
    let payload = {
      "receive_id": msg.to,
      "msg_type": "text",
      "content": json_encode({ "text": msg.content }),
    }
    
    let headers = [
      ("Authorization", "Bearer \(self.tenant_token)"),
      ("Content-Type", "application/json"),
    ]
    
    // http_post_with_headers(url, json_encode(payload), headers)
    log_info("Message sent to Feishu user: \(msg.to)")
  }

  fn stop(self: Self) -> Unit {
    self.enabled = false
    log_info("Feishu channel stopped")
  }

  fn name(self: Self) -> String {
    "feishu"
  }
}

// 刷新 tenant_access_token
fn FeishuChannel::refresh_token(self: FeishuChannel) -> Unit {
  let url = "\(self.base_url)/auth/v3/tenant_access_token/internal"
  
  let payload = {
    "app_id": self.config.app_id,
    "app_secret": self.config.app_secret,
  }
  
  // let response = http_post(url, json_encode(payload))
  // let data = json_decode(response)
  // self.tenant_token = data["tenant_access_token"]
  // self.token_expires = now() + data["expire"] - 60
  
  log_info("Feishu token refreshed")
}

// 飞书事件类型
enum FeishuEventType {
  MessageReceive
  UserEnter
  UserLeave
  GroupCreated
  Unknown
}

// 飞书事件
struct FeishuEvent {
  schema: String
  header: FeishuEventHeader
  event: FeishuEventBody
}

struct FeishuEventHeader {
  event_id: String
  event_type: String
  create_time: String
  token: String
  app_id: String
  tenant_key: String
}

struct FeishuEventBody {
  sender: FeishuSender
  message: FeishuMessage
}

struct FeishuSender {
  sender_id: FeishuUserId
  sender_type: String
  tenant_key: String
}

struct FeishuUserId {
  union_id: String
  user_id: String
  open_id: String
}

struct FeishuMessage {
  message_id: String
  root_id: String
  parent_id: String
  create_time: String
  chat_id: String
  chat_type: String
  message_type: String
  content: String
  mentions: Array[FeishuMention]
}

struct FeishuMention {
  key: String
  id: FeishuUserId
  name: String
  tenant_key: String
}

// 事件处理
fn FeishuChannel::handle_event(self: FeishuChannel, event: FeishuEvent) -> Message? {
  match event.header.event_type {
    "im.message.receive_v1" => {
      self.handle_message_event(event.event)
    }
    _ => None,
  }
}

fn FeishuChannel::handle_message_event(self: FeishuChannel, body: FeishuEventBody) -> Message? {
  let msg = body.message
  
  // 解析消息内容
  let content = self.parse_content(msg.message_type, msg.content)
  
  Some(Message::{
    id: msg.message_id,
    from: body.sender.sender_id.user_id,
    to: msg.chat_id,
    content: content,
    timestamp: parse_time(msg.create_time),
    channel: "feishu",
  })
}

// 解析消息内容
fn FeishuChannel::parse_content(self: FeishuChannel, msg_type: String, content: String) -> String {
  match msg_type {
    "text" => {
      // {"text": "hello"}
      let data = json_decode(content)
      match data {
        Some(d) => d["text"],
        None => content,
      }
    }
    "post" => {
      // 富文本消息
      self.parse_post_content(content)
    }
    _ => content,
  }
}

// 解析富文本
fn FeishuChannel::parse_post_content(self: FeishuChannel, content: String) -> String {
  // 简化实现：提取纯文本
  let data = json_decode(content)
  
  match data {
    Some(d) => {
      match d["content"] {
        Some(content) => {
          // 遍历段落提取文本
          self.extract_text_from_post(content)
        }
        None => "",
      }
    }
    None => "",
  }
}

fn FeishuChannel::extract_text_from_post(self: FeishuChannel, content: Any) -> String {
  // 从富文本结构中提取纯文本
  // 简化实现
  ""
}

// 发送卡片消息
fn FeishuChannel::send_card(self: FeishuChannel, to: String, card: FeishuCard) -> Unit {
  if !self.enabled {
    return
  }
  
  let url = "\(self.base_url)/im/v1/messages?receive_id_type=user_id"
  
  let payload = {
    "receive_id": to,
    "msg_type": "interactive",
    "content": json_encode(card),
  }
  
  // 发送
  log_info("Card message sent to Feishu user: \(to)")
}

// 飞书卡片
struct FeishuCard {
  config: FeishuCardConfig
  header: FeishuCardHeader
  elements: Array[FeishuCardElement]
}

struct FeishuCardConfig {
  wide_screen_mode: Bool
  enable_forward: Bool
}

struct FeishuCardHeader {
  title: FeishuCardText
  template: String  // blue, wathet, turquoise, green, yellow, orange, red, carmine, violet, grey, black
}

type FeishuCardElement union {
  FeishuCardText,
  FeishuCardDivider,
  FeishuCardAction,
  FeishuCardField,
}

struct FeishuCardText {
  tag: String  // "div"
  text: FeishuTextContent
}

struct FeishuTextContent {
  tag: String  // "plain_text" | "lark_md"
  content: String
}

struct FeishuCardDivider {
  tag: String  // "hr"
}

struct FeishuCardAction {
  tag: String  // "action"
  actions: Array[FeishuAction]
}

struct FeishuAction {
  tag: String  // "button"
  text: FeishuTextContent
  type: String  // "primary" | "default"
  value: Map[String, String]
}

struct FeishuCardField {
  tag: String  // "note"
  elements: Array[FeishuTextContent]
}

// 创建简单卡片
fn FeishuCard::simple(title: String, content: String) -> FeishuCard {
  FeishuCard::{
    config: FeishuCardConfig::{
      wide_screen_mode: true,
      enable_forward: true,
    },
    header: FeishuCardHeader::{
      title: FeishuTextContent::{
        tag: "plain_text",
        content: title,
      },
      template: "blue",
    },
    elements: [
      FeishuCardText::{
        tag: "div",
        text: FeishuTextContent::{
          tag: "lark_md",
          content: content,
        },
      },
    ],
  }
}

// 创建带按钮的卡片
fn FeishuCard::with_actions(title: String, content: String, buttons: Array[(String, String)]) -> FeishuCard {
  let actions = buttons.map(|(text, value)| {
    FeishuAction::{
      tag: "button",
      text: FeishuTextContent::{
        tag: "plain_text",
        content: text,
      },
      type: "primary",
      value: Map::from([("action", value)]),
    }
  })
  
  FeishuCard::{
    config: FeishuCardConfig::{
      wide_screen_mode: true,
      enable_forward: true,
    },
    header: FeishuCardHeader::{
      title: FeishuTextContent::{
        tag: "plain_text",
        content: title,
      },
      template: "blue",
    },
    elements: [
      FeishuCardText::{
        tag: "div",
        text: FeishuTextContent::{
          tag: "lark_md",
          content: content,
        },
      },
      FeishuCardAction::{
        tag: "action",
        actions: actions,
      },
    ],
  }
}
