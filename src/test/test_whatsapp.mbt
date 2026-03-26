// XiaoClaw - WhatsApp 通道测试
// 覆盖：Channel 方法、按钮、Payload 构造、事件解析、HTTP 安全包装

// ============ WhatsAppChannel 基本测试 ============

fn test_whatsapp_channel_new() -> TestResult {
  let cfg = WhatsAppConfig::{
    api_url: "https://api.example.com",
    api_key: "test-key",
    phone_number_id: "123456",
    webhook_verify_token: "token",
    enabled: true,
  }
  let ch = WhatsAppChannel::new(cfg)
  let passed = ch.enabled == true &&
    ch.base_url == "https://api.example.com"

  { name: "WhatsAppChannel::new 初始化正确", passed, message: if passed { "ok" } else { "初始化字段不正确" }, duration: 0 }
}

fn test_whatsapp_channel_start_stop() -> TestResult {
  let cfg = WhatsAppConfig::{ api_url: "", api_key: "", phone_number_id: "", webhook_verify_token: "", enabled: false }
  let ch = WhatsAppChannel::new(cfg)

  ch.start()
  let started_ok = ch.enabled == true

  ch.stop()
  let stopped_ok = ch.enabled == false

  let passed = started_ok && stopped_ok

  { name: "WhatsAppChannel::start/stop 切换 enabled", passed, message: if passed { "ok" } else { "enabled 状态切换不正确" }, duration: 0 }
}

fn test_whatsapp_channel_name() -> TestResult {
  let cfg = WhatsAppConfig::{ api_url: "", api_key: "", phone_number_id: "", webhook_verify_token: "", enabled: false }
  let ch = WhatsAppChannel::new(cfg)
  let passed = ch.name() == "whatsapp"

  { name: "WhatsAppChannel::name 返回 whatsapp", passed, message: if passed { "ok" } else { "name 不正确" }, duration: 0 }
}

// ============ WhatsAppButton 测试 ============

fn test_whatsapp_button_quick_reply() -> TestResult {
  let btn = WhatsAppButton::quick_reply("btn-1", "是的")
  let passed = match btn.kind {
    QuickReply => true
    _ => false
  } && btn.id == "btn-1" &&
    btn.title == "是的" &&
    btn.url.is_empty()

  { name: "WhatsAppButton::quick_reply（Fix #23）", passed, message: if passed { "ok" } else { "按钮字段不正确" }, duration: 0 }
}

fn test_whatsapp_button_url() -> TestResult {
  // 🔴 Fix #23: URL 按钮现在存储 URL
  let btn = WhatsAppButton::url_button("btn-url", "打开链接", "https://example.com")
  let passed = match btn.kind {
    Url => true
    _ => false
  } && btn.id == "btn-url" &&
    btn.title == "打开链接" &&
    btn.url == Some("https://example.com")

  { name: "WhatsAppButton::url_button 存储 URL（Fix #23）", passed, message: if passed { "ok" } else { "URL 未存储" }, duration: 0 }
}

fn test_whatsapp_button_url_without_url() -> TestResult {
  // 错误构造：URL 按钮不给 URL
  let btn = WhatsAppButton::url_button("btn", "标题", "")
  // 空 URL 也应该存储（由调用方验证）
  let passed = btn.url == Some("")

  { name: "WhatsAppButton::url_button 空 URL", passed, message: if passed { "ok" } else { "空 URL 处理不正确" }, duration: 0 }
}

// ============ Payload 构造测试 ============

fn test_build_text_payload() -> TestResult {
  let payload = build_text_payload("8612345678901", "你好，世界")
  let passed = payload.contains("\"messaging_product\":\"whatsapp\"") &&
    payload.contains("\"to\":\"8612345678901\"") &&
    payload.contains("\"type\":\"text\"") &&
    payload.contains("\"body\":\"你好，世界\"")

  { name: "build_text_payload::格式正确", passed, message: if passed { "ok" } else { "payload 格式不正确" }, duration: 0 }
}

fn test_build_image_payload() -> TestResult {
  let payload = build_image_payload("8612345678901", "https://img.example.com/pic.jpg", "看这张图")
  let passed = payload.contains("\"type\":\"image\"") &&
    payload.contains("\"link\":\"https://img.example.com/pic.jpg\"") &&
    payload.contains("\"caption\":\"看这张图\"")

  { name: "build_image_payload::格式正确", passed, message: if passed { "ok" } else { "payload 格式不正确" }, duration: 0 }
}

fn test_build_image_payload_no_caption() -> TestResult {
  // 🔴 Fix #24 验证：无 caption 时为空字符串
  let payload = build_image_payload("8612345678901", "https://img.example.com/pic.jpg", "")
  let passed = payload.contains("\"caption\":\"\"")

  { name: "build_image_payload::无 caption 为空字符串（Fix #24）", passed, message: if passed { "ok" } else { "caption 处理不正确" }, duration: 0 }
}

fn test_build_buttons_payload_quick_reply() -> TestResult {
  let buttons = [
    WhatsAppButton::quick_reply("btn-yes", "是"),
    WhatsAppButton::quick_reply("btn-no", "否"),
  ]
  let payload = build_buttons_payload("8612345678901", "确认操作？", buttons)
  let passed = payload.contains("\"type\":\"interactive\"") &&
    payload.contains("\"type\":\"reply\"") &&
    payload.contains("\"btn-yes\"") &&
    payload.contains("\"btn-no\"")

  { name: "build_buttons_payload::quick_reply 按钮", passed, message: if passed { "ok" } else { "payload 不含按钮" }, duration: 0 }
}

fn test_build_buttons_payload_url() -> TestResult {
  // 🔴 Fix #23 验证：URL 按钮在 payload 中包含 url 字段
  let buttons = [
    WhatsAppButton::url_button("btn-url", "打开官网", "https://example.com"),
  ]
  let payload = build_buttons_payload("8612345678901", "访问链接", buttons)
  let passed = payload.contains("\"type\":\"url\"") &&
    payload.contains("\"https://example.com\"")

  { name: "build_buttons_payload::url 按钮含 URL（Fix #23）", passed, message: if passed { "ok" } else { "payload 不含 URL" }, duration: 0 }
}

fn test_build_template_payload() -> TestResult {
  let components : Array[Map[String, String]] = []
  components.push({ "type": "header", "text": "标题" })
  components.push({ "type": "body", "text": "内容" })

  let payload = build_template_payload("8612345678901", "hello_world", components)
  let passed = payload.contains("\"type\":\"template\"") &&
    payload.contains("\"name\":\"hello_world\"") &&
    payload.contains("\"code\":\"zh_CN\"")

  { name: "build_template_payload::格式正确", passed, message: if passed { "ok" } else { "payload 格式不正确" }, duration: 0 }
}

// ============ HTTP 安全包装测试 ============

fn test_try_http_post_returns_error() -> TestResult {
  // 🔴 Fix #20: HTTP 调用明确返回错误而非静默失败
  let result = try_http_post("https://api.example.com/messages", "{}", "key")
  let passed = match result {
    Err(_) => true
    _ => false
  }

  { name: "try_http_post::WASM 环境返回错误而非 panic（Fix #20）", passed, message: if passed { "ok" } else { "应返回 Err" }, duration: 0 }
}

// ============ Webhook 事件解析测试 ============

fn test_parse_whatsapp_event_returns_error() -> TestResult {
  // 🔴 Fix #21: JSON 解析需要宿主实现，明确返回错误
  let result = parse_whatsapp_event("invalid json")
  let passed = match result {
    Err(_) => true
    _ => false
  }

  { name: "parse_whatsapp_event::无效 JSON 返回 Err（Fix #21）", passed, message: if passed { "ok" } else { "应返回 Err" }, duration: 0 }
}

fn test_whatsapp_message_type_field() -> TestResult {
  // 🔴 Fix #26: msg_type 字段替代保留字 type
  let msg = WhatsAppMessage::{
    from: "8612345678901",
    id: "msg-123",
    timestamp: "1700000000",
    msg_type: "text",  // renamed from `type`
    text: Some({ body: "你好" }),
    image: None,
    document: None,
    audio: None,
    video: None,
    location: None,
    sticker: None,
  }
  let passed = msg.msg_type == "text" &&
    match msg.text {
      Some(t) => t.body == "你好"
      None => false
    }

  { name: "WhatsAppMessage::msg_type 字段可用（Fix #26）", passed, message: if passed { "ok" } else { "字段访问失败" }, duration: 0 }
}

fn test_whatsapp_message_type_unknown() -> TestResult {
  // 未知的消息类型不 panic
  let msg = WhatsAppMessage::{
    from: "8612345678901",
    id: "msg-999",
    timestamp: "1700000000",
    msg_type: "sticker",
    text: None,
    image: None,
    document: None,
    audio: None,
    video: None,
    location: None,
    sticker: Some({ id: "sticker-1", mime_type: "image/webp", sha256: "abc" }),
  }
  let passed = msg.msg_type == "sticker"

  { name: "WhatsAppMessage::未知类型不 panic", passed, message: if passed { "ok" } else { "panic 了" }, duration: 0 }
}

// ============ extract_messages 测试 ============

fn test_extract_messages_empty_event() -> TestResult {
  // 🔴 Fix #22: 空事件不 panic
  let cfg = WhatsAppConfig::{ api_url: "", api_key: "", phone_number_id: "123", webhook_verify_token: "", enabled: false }
  let ch = WhatsAppChannel::new(cfg)

  let empty_event = { object: "whatsapp_business_account", entry: [] }
  let msgs = ch.extract_messages(empty_event)
  let passed = msgs.length() == 0

  { name: "extract_messages::空事件返回空数组（Fix #22）", passed, message: if passed { "ok" } else { "应返回空数组" }, duration: 0 }
}

// ============ 测试套件注册 ============

fn whatsapp_test_suite() -> TestSuite {
  TestSuite::{
    name: "WhatsApp",
    tests: [
      test_whatsapp_channel_new,
      test_whatsapp_channel_start_stop,
      test_whatsapp_channel_name,
      test_whatsapp_button_quick_reply,
      test_whatsapp_button_url,
      test_whatsapp_button_url_without_url,
      test_build_text_payload,
      test_build_image_payload,
      test_build_image_payload_no_caption,
      test_build_buttons_payload_quick_reply,
      test_build_buttons_payload_url,
      test_build_template_payload,
      test_try_http_post_returns_error,
      test_parse_whatsapp_event_returns_error,
      test_whatsapp_message_type_field,
      test_whatsapp_message_type_unknown,
      test_extract_messages_empty_event,
    ],
    setup: None,
    teardown: None,
  }
}
