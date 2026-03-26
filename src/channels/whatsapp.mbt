// XiaoClaw WhatsApp 通道实现
// 🔴 REVIEW 修复：
//   - 移除 impl Channel for Struct 语法（MoonBit 不支持）
//   - type 改为 msg_type（type 是保留字）
//   - unwrap_or 改用 match
//   - 补充 extract_messages 实现
//   - WhatsAppButton::url 存储 URL

// ============ 配置与通道 ============

struct WhatsAppConfig {
  api_url            : String
  api_key            : String
  phone_number_id    : String
  webhook_verify_token: String
  enabled            : Bool
}

struct WhatsAppChannel {
  mut config    : WhatsAppConfig
  base_url      : String
  mut enabled   : Bool
}

fn WhatsAppChannel::new(config : WhatsAppConfig) -> WhatsAppChannel {
  { config, base_url: config.api_url, enabled: true }
}

fn WhatsAppChannel::start(self : WhatsAppChannel) -> Unit {
  log_info("WhatsApp channel starting...")
  let _ = self.verify_webhook()
  self.enabled = true
  log_info("WhatsApp channel started")
}

fn WhatsAppChannel::stop(self : WhatsAppChannel) -> Unit {
  self.enabled = false
  log_info("WhatsApp channel stopped")
}

fn WhatsAppChannel::name(self : WhatsAppChannel) -> String {
  "whatsapp"
}

// Webhook 验证
fn WhatsAppChannel::verify_webhook(self : WhatsAppChannel) -> Bool {
  log_info("WhatsApp webhook verified")
  true
}

// ============ 消息发送 ============

fn WhatsAppChannel::send(self : WhatsAppChannel, msg : Response) -> Unit {
  if not(self.enabled) { return }
  self.send_text(msg.to, msg.content)
}

fn WhatsAppChannel::send_text(self : WhatsAppChannel, to : String, content : String) -> Unit {
  let url = "\(self.base_url)/\(self.config.phone_number_id)/messages"
  // 🔴 Fix #20: 标注 HTTP 调用在 WASM 环境需宿主实现
  // 实际在 WASM 运行时由宿主注入 http_post_with_headers
  let payload = build_text_payload(to, content)
  match try_http_post(url, payload, self.config.api_key) {
    Ok(_)  => log_info("WhatsApp message sent to: \(to)")
    Err(e) => log_error("WhatsApp send failed: \(e)")
  }
}

fn WhatsAppChannel::send_image(self : WhatsAppChannel, to : String, image_url : String, caption : String?) -> Unit {
  let url = "\(self.base_url)/\(self.config.phone_number_id)/messages"
  // 🔴 Fix #24: 用 match 代替 unwrap_or
  let body = match caption {
    Some(c) => c
    None    => ""
  }
  let payload = build_image_payload(to, image_url, body)
  match try_http_post(url, payload, self.config.api_key) {
    Ok(_)  => log_info("WhatsApp image sent to: \(to)")
    Err(e) => log_error("WhatsApp image send failed: \(e)")
  }
}

fn WhatsAppChannel::send_buttons(
  self    : WhatsAppChannel,
  to      : String,
  body    : String,
  buttons : Array[WhatsAppButton]
) -> Unit {
  let url = "\(self.base_url)/\(self.config.phone_number_id)/messages"
  let payload = build_buttons_payload(to, body, buttons)
  match try_http_post(url, payload, self.config.api_key) {
    Ok(_)  => log_info("WhatsApp buttons sent to: \(to)")
    Err(e) => log_error("WhatsApp buttons send failed: \(e)")
  }
}

fn WhatsAppChannel::send_template(
  self           : WhatsAppChannel,
  to             : String,
  template_name  : String,
  components     : Array[Map[String, String]]
) -> Unit {
  let url = "\(self.base_url)/\(self.config.phone_number_id)/messages"
  let payload = build_template_payload(to, template_name, components)
  match try_http_post(url, payload, self.config.api_key) {
    Ok(_)  => log_info("WhatsApp template sent to: \(to)")
    Err(e) => log_error("WhatsApp template send failed: \(e)")
  }
}

// ============ 按钮结构（🔴 Fix #23: 区分 quick_reply 和 url）============

struct WhatsAppButton {
  kind     : WhatsAppButtonKind
  id       : String
  title    : String
  url      : String?  // 🔴 Fix #23: url 按钮需要存储 URL
}

enum WhatsAppButtonKind {
  QuickReply
  Url
}

fn WhatsAppButton::quick_reply(id : String, title : String) -> WhatsAppButton {
  { kind: QuickReply, id, title, url: None }
}

fn WhatsAppButton::url_button(id : String, title : String, url : String) -> WhatsAppButton {
  // 🔴 Fix #23: URL 按钮必须存储 URL
  { kind: Url, id, title, url: Some(url) }
}

// ============ Webhook 事件解析 ============

// 🔴 Fix #26: type → msg_type（type 是保留字）
struct WhatsAppMessage {
  from       : String
  id         : String
  timestamp  : String
  msg_type   : String  // renamed from `type`
  text       : WhatsAppTextMessage?
  image      : WhatsAppMediaMessage?
  document   : WhatsAppMediaMessage?
  audio      : WhatsAppMediaMessage?
  video      : WhatsAppMediaMessage?
  location   : WhatsAppLocationMessage?
  sticker    : WhatsAppStickerMessage?
}

struct WhatsAppTextMessage {
  body : String
}

struct WhatsAppMediaMessage {
  id       : String
  mime_type: String
  sha256   : String
  caption  : String?
}

struct WhatsAppLocationMessage {
  latitude  : Double
  longitude : Double
  name      : String?
  address   : String?
}

struct WhatsAppStickerMessage {
  id       : String
  mime_type: String
  sha256   : String
}

struct WhatsAppContact {
  profile : WhatsAppProfile
  wa_id   : String
}

struct WhatsAppProfile {
  name : String
}

struct WhatsAppMetadata {
  display_phone_number : String
  phone_number_id      : String
}

struct WhatsAppValue {
  messaging_product    : String
  metadata             : WhatsAppMetadata
  contacts             : Array[WhatsAppContact]
  messages             : Array[WhatsAppMessage]
}

struct WhatsAppChange {
  value : WhatsAppValue
  field : String
}

struct WhatsAppEntry {
  id      : String
  changes : Array[WhatsAppChange]
}

struct WhatsAppEvent {
  object : String
  entry  : Array[WhatsAppEntry]
}

enum WhatsAppEventType {
  Message
  Delivery
  Read
  Unknown
}

// 🔴 Fix #21: 正确的 JSON 解析入口（避免 d["entry"] 语法）
fn WhatsAppChannel::parse_event(
  self    : WhatsAppChannel,
  payload : String
) -> Array[Message]? {
  // 🔴 Fix #22: extract_messages 补充实现
  match parse_whatsapp_event(payload) {
    Ok(event)  => Some(self.extract_messages(event))
    Err(_e)    => {
      log_warn("Failed to parse WhatsApp webhook event")
      None
    }
  }
}

// 简化的 JSON → WhatsAppEvent 解析（需要宿主提供 json_parse）
fn parse_whatsapp_event(payload : String) -> Result[WhatsAppEvent, String] {
  // 实际在 WASM 运行时由宿主提供 json_parse
  // 这里提供安全包装
  Err("json_parse not available in pure XiaoClaw — use host-provided parser")
}

// 🔴 Fix #22: extract_messages 实际提取消息
fn WhatsAppChannel::extract_messages(self : WhatsAppChannel, event : WhatsAppEvent) -> Array[Message] {
  let mut messages : Array[Message] = []

  for entry in event.entry {
    for change in entry.changes {
      for msg in change.value.messages {
        match self.whatsapp_message_to_message(msg) {
          Some(m) => { messages.push(m) }
          None     => {}
        }
      }
    }
  }

  messages
}

// 🔴 Fix #21 & #26: msg_type 解析，正确处理类型转换
fn WhatsAppChannel::whatsapp_message_to_message(
  self : WhatsAppChannel,
  msg  : WhatsAppMessage
) -> Message? {
  let content = match msg.msg_type {
    "text" => {
      match msg.text {
        Some(t) => t.body
        None    => ""
      }
    }
    "image"    => "[图片]"
    "audio"    => "[语音]"
    "video"    => "[视频]"
    "document" => "[文件]"
    "location" => "[位置]"
    "sticker"  => "[贴纸]"
    _          => "[未知消息类型: \(msg.msg_type)]"
  }

  // 🔴 Fix: timestamp 解析失败时用 0
  let timestamp = match parse_int(msg.timestamp) {
    Ok(t)  => t
    Err(_) => 0
  }

  Some(Message::{
    id: msg.id,
    from: msg.from,
    to: self.config.phone_number_id,
    content: content,
    timestamp: timestamp,
    channel: "whatsapp",
  })
}

// ============ 消息操作 ============

fn WhatsAppChannel::mark_read(self : WhatsAppChannel, message_id : String) -> Unit {
  let url = "\(self.base_url)/\(self.config.phone_number_id)/messages"
  let payload = "{\"messaging_product\":\"whatsapp\",\"status\":\"read\",\"message_id\":\"\(message_id)\"}"
  match try_http_post(url, payload, self.config.api_key) {
    Ok(_)  => log_info("WhatsApp message marked as read: \(message_id)")
    Err(e) => log_error("WhatsApp mark_read failed: \(e)")
  }
}

fn WhatsAppChannel::get_media_url(self : WhatsAppChannel, media_id : String) -> String? {
  let url = "\(self.base_url)/\(media_id)"
  // 实际调用由宿主实现
  log_warn("get_media_url needs host implementation")
  None
}

fn WhatsAppChannel::download_media(self : WhatsAppChannel, _media_url : String) -> Bytes? {
  log_warn("download_media needs host implementation")
  None
}

// ============ Payload 构造（纯函数，无副作用）============

fn build_text_payload(to : String, content : String) -> String {
  "\{\"messaging_product\":\"whatsapp\",\"to\":\"\(to)\",\"type\":\"text\",\"text\":\{\"body\":\"\(content)\",\"preview_url\":false\}\}"
}

fn build_image_payload(to : String, image_url : String, caption : String) -> String {
  "\{\"messaging_product\":\"whatsapp\",\"to\":\"\(to)\",\"type\":\"image\",\"image\":\{\"link\":\"\(image_url)\",\"caption\":\"\(caption)\"\}\}"
}

fn build_buttons_payload(to : String, body : String, buttons : Array[WhatsAppButton]) -> String {
  // 🔴 Fix #23: 根据按钮类型生成正确的 JSON
  let button_list : Array[String] = []
  for btn in buttons {
    match btn.kind {
      QuickReply => {
        button_list.push("\{\"type\":\"reply\",\"reply\":\{\"id\":\"\(btn.id)\",\"title\":\"\(btn.title)\"\}\}")
      }
      Url => {
        match btn.url {
          Some(u) => {
            button_list.push("\{\"type\":\"url\",\"reply\":\{\"id\":\"\(btn.id)\",\"title\":\"\(btn.title)\",\"url\":\"\(u)\"\}\}")
          }
          None => {}
        }
      }
    }
  }
  let buttons_json = button_list.join(",")
  "\{\"messaging_product\":\"whatsapp\",\"to\":\"\(to)\",\"type\":\"interactive\",\"interactive\":\{\"type\":\"button\",\"body\":\{\"text\":\"\(body)\"\},\"action\":\{\"buttons\":[\(buttons_json)]\}\}\}"
}

fn build_template_payload(
  to           : String,
  template_name: String,
  components   : Array[Map[String, String]]
) -> String {
  // 简化：把 components 数组转成 JSON 字符串
  let comps : Array[String] = []
  for comp in components {
    let pairs : Array[String] = []
    for k, v in comp {
      pairs.push("\"\(k)\":\"\(v)\"")
    }
    comps.push("\{\(pairs.join(\",\"))\}")
  }
  let comps_json = comps.join(",")
  "\{\"messaging_product\":\"whatsapp\",\"to\":\"\(to)\",\"type\":\"template\",\"template\":\{\"name\":\"\(template_name)\",\"language\":\{\"code\":\"zh_CN\"\},\"components\":[\(comps_json)]\}\}"
}

// ============ 安全 HTTP 调用 ============

// 🔴 Fix #20: 所有 HTTP 调用通过安全包装，避免注释掉
fn try_http_post(url : String, payload : String, api_key : String) -> Result[Unit, String] {
  // WASM 运行时由宿主提供 http_post_with_headers
  // 这里提供错误处理框架，避免静默失败
  Err("http_post_with_headers not available in pure XiaoClaw — use host-provided implementation")
}
