// XiaoClaw - Lightweight AI Assistant
// Powered by MoonBit and WebAssembly

fn main {
  let config = Config::load()
  let app = XiaoClaw::new(config)
  
  app.start()
}

// XiaoClaw 主结构
struct XiaoClaw {
  config: Config
  channels: Array[Channel]
  agent: Agent
  scheduler: Scheduler
  memory: MemoryStore
}

fn XiaoClaw::new(config: Config) -> XiaoClaw {
  XiaoClaw::{
    config: config,
    channels: [],
    agent: Agent::new(config.agent),
    scheduler: Scheduler::new(),
    memory: MemoryStore::new(config.memory),
  }
}

fn XiaoClaw::start(self: XiaoClaw) -> Unit {
  // 启动所有通道
  for channel in self.channels {
    channel.start()
  }
  
  // 启动调度器
  self.scheduler.start()
  
  // 主循环
  self.main_loop()
}

fn XiaoClaw::main_loop(self: XiaoClaw) -> Unit {
  loop {
    // 接收消息
    let message = self.receive_message()
    
    match message {
      Some(msg) => {
        // 处理消息
        let response = self.handle_message(msg)
        // 发送回复
        self.send_response(response)
      }
      None => {
        // 等待
        sleep(100)
      }
    }
  }
}

fn XiaoClaw::handle_message(self: XiaoClaw, msg: Message) -> Response {
  // 加载上下文
  let context = self.memory.load_context(msg.from)
  
  // 调用 AI
  let reply = self.agent.chat(msg.content, context)
  
  // 保存上下文
  self.memory.save_context(msg.from, context.append(msg, reply))
  
  Response::{
    to: msg.from,
    content: reply,
    channel: msg.channel,
  }
}