// XiaoClaw 消息通道模块

// 消息结构
struct Message {
  id: String
  from: String
  to: String
  content: String
  timestamp: Int
  channel: String
}

// 回复结构
struct Response {
  to: String
  content: String
  channel: String
}

// Channel trait
trait Channel {
  fn start(self: Self) -> Unit
  fn receive(self: Self) -> Message?
  fn send(self: Self, msg: Response) -> Unit
  fn stop(self: Self) -> Unit
  fn name(self: Self) -> String
}

// 通道注册表
struct ChannelRegistry {
  channels: Map[String, Channel]
}

fn ChannelRegistry::new() -> ChannelRegistry {
  ChannelRegistry::{
    channels: Map::new(),
  }
}

fn ChannelRegistry::register(self: ChannelRegistry, channel: Channel) -> Unit {
  self.channels.insert(channel.name(), channel)
}

fn ChannelRegistry::get(self: ChannelRegistry, name: String) -> Channel? {
  self.channels.get(name)
}

fn ChannelRegistry::start_all(self: ChannelRegistry) -> Unit {
  for (name, channel) in self.channels {
    channel.start()
    log_info("Channel started: \(name)")
  }
}

fn ChannelRegistry::stop_all(self: ChannelRegistry) -> Unit {
  for (name, channel) in self.channels {
    channel.stop()
    log_info("Channel stopped: \(name)")
  }
}