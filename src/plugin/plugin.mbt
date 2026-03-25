// XiaoClaw Plugin 系统

// 插件元数据
struct PluginMeta {
  name: String
  version: String
  author: String
  description: String
  dependencies: Array[String]
}

// 插件接口
trait Plugin {
  // 元数据
  fn meta(self: Self) -> PluginMeta
  
  // 生命周期
  fn on_load(self: Self, ctx: PluginContext) -> Result[Unit]
  fn on_enable(self: Self) -> Unit
  fn on_disable(self: Self) -> Unit
  fn on_unload(self: Self) -> Unit
  
  // 消息处理 (可选)
  fn on_message(self: Self, msg: Message) -> Option[Response] {
    None
  }
  
  // 命令处理 (可选)
  fn on_command(self: Self, cmd: String, args: Array[String]) -> Option[String] {
    None
  }
}

// 插件上下文
struct PluginContext {
  config: Config
  logger: Logger
  store: MemoryStore
  agent: Agent
}

// 插件状态
enum PluginState {
  Unloaded
  Loaded
  Enabled
  Disabled
  Error(String)
}

// 插件实例
struct PluginInstance {
  plugin: Plugin
  state: PluginState
  load_time: Int
  error_count: Int
}

// 插件管理器
struct PluginManager {
  plugins: Map[String, PluginInstance]
  context: PluginContext
  plugin_dir: String
  auto_enable: Bool
}

fn PluginManager::new(ctx: PluginContext, plugin_dir: String) -> PluginManager {
  PluginManager::{
    plugins: Map::new(),
    context: ctx,
    plugin_dir: plugin_dir,
    auto_enable: true,
  }
}

// 注册插件
fn PluginManager::register(self: PluginManager, plugin: Plugin) -> Result[Unit] {
  let meta = plugin.meta()
  let name = meta.name
  
  // 检查依赖
  match self.check_dependencies(meta.dependencies) {
    Err(e) => return Err(e),
    Ok(_) => {},
  }
  
  // 创建实例
  let instance = PluginInstance::{
    plugin: plugin,
    state: Unloaded,
    load_time: 0,
    error_count: 0,
  }
  
  self.plugins.insert(name, instance)
  
  log_info("Plugin registered: \(name) v\(meta.version)")
  
  Ok(())
}

// 加载插件
fn PluginManager::load(self: PluginManager, name: String) -> Result[Unit] {
  match self.plugins.get(name) {
    None => Err(PluginNotFound(name)),
    Some(instance) => {
      match instance.state {
        Loaded | Enabled => Ok(()),  // 已加载
        _ => {
          match instance.plugin.on_load(self.context) {
            Ok(_) => {
              instance.state = Loaded
              instance.load_time = now()
              
              // 自动启用
              if self.auto_enable {
                self.enable(name)?
              }
              
              log_info("Plugin loaded: \(name)")
              Ok(())
            }
            Err(e) => {
              instance.state = Error(error_to_string(e))
              Err(PluginInitFailed(name))
            }
          }
        }
      }
    }
  }
}

// 启用插件
fn PluginManager::enable(self: PluginManager, name: String) -> Result[Unit] {
  match self.plugins.get(name) {
    None => Err(PluginNotFound(name)),
    Some(instance) => {
      match instance.state {
        Enabled => Ok(()),  // 已启用
        Loaded => {
          instance.plugin.on_enable()
          instance.state = Enabled
          log_info("Plugin enabled: \(name)")
          Ok(())
        }
        _ => Err(PluginError("Plugin must be loaded first: \(name)")),
      }
    }
  }
}

// 禁用插件
fn PluginManager::disable(self: PluginManager, name: String) -> Result[Unit] {
  match self.plugins.get(name) {
    None => Err(PluginNotFound(name)),
    Some(instance) => {
      match instance.state {
        Enabled => {
          instance.plugin.on_disable()
          instance.state = Disabled
          log_info("Plugin enabled: \(name)")
          Ok(())
        }
        _ => Ok(()),  // 本来就是禁用状态
      }
    }
  }
}

// 卸载插件
fn PluginManager::unload(self: PluginManager, name: String) -> Result[Unit] {
  match self.plugins.get(name) {
    None => Err(PluginNotFound(name)),
    Some(instance) => {
      // 先禁用
      if instance.state == Enabled {
        instance.plugin.on_disable()
      }
      
      // 卸载
      instance.plugin.on_unload()
      instance.state = Unloaded
      
      log_info("Plugin unloaded: \(name)")
      Ok(())
    }
  }
}

// 处理消息
fn PluginManager::on_message(self: PluginManager, msg: Message) -> Option[Response] {
  for (name, instance) in self.plugins {
    if instance.state == Enabled {
      match instance.plugin.on_message(msg) {
        Some(response) => return Some(response),
        None => {},
      }
    }
  }
  None
}

// 处理命令
fn PluginManager::on_command(self: PluginManager, cmd: String, args: Array[String]) -> Option[String] {
  for (name, instance) in self.plugins {
    if instance.state == Enabled {
      match instance.plugin.on_command(cmd, args) {
        Some(result) => return Some(result),
        None => {},
      }
    }
  }
  None
}

// 检查依赖
fn PluginManager::check_dependencies(self: PluginManager, deps: Array[String]) -> Result[Unit] {
  for dep in deps {
    match self.plugins.get(dep) {
      None => return Err(PluginNotFound("Missing dependency: \(dep)")),
      Some(instance) => {
        if instance.state != Enabled {
          return Err(PluginError("Dependency not enabled: \(dep)"))
        }
      }
    }
  }
  Ok(())
}

// 获取插件列表
fn PluginManager::list(self: PluginManager) -> Array[PluginInfo] {
  let mut result = []
  
  for (name, instance) in self.plugins {
    let meta = instance.plugin.meta()
    result.push(PluginInfo::{
      name: name,
      version: meta.version,
      author: meta.author,
      description: meta.description,
      state: instance.state,
      load_time: instance.load_time,
    })
  }
  
  result
}

// 插件信息
struct PluginInfo {
  name: String
  version: String
  author: String
  description: String
  state: PluginState
  load_time: Int
}

// 内置插件示例: 健康检查插件
struct HealthCheckPlugin {
  check_interval: Int
  last_check: Int
}

fn HealthCheckPlugin::new() -> HealthCheckPlugin {
  HealthCheckPlugin::{
    check_interval: 60000,  // 1分钟
    last_check: 0,
  }
}

impl Plugin for HealthCheckPlugin {
  fn meta(self: Self) -> PluginMeta {
    PluginMeta::{
      name: "health-check",
      version: "1.0.0",
      author: "Deep Sea Team",
      description: "Periodic health check plugin",
      dependencies: [],
    }
  }
  
  fn on_load(self: Self, ctx: PluginContext) -> Result[Unit] {
    log_info("Health check plugin loaded")
    Ok(())
  }
  
  fn on_enable(self: Self) -> Unit {
    log_info("Health check plugin enabled")
  }
  
  fn on_disable(self: Self) -> Unit {
    log_info("Health check plugin disabled")
  }
  
  fn on_unload(self: Self) -> Unit {
    log_info("Health check plugin unloaded")
  }
  
  fn on_command(self: Self, cmd: String, args: Array[String]) -> Option[String] {
    match cmd {
      "health" => Some("✅ All systems healthy"),
      "ping" => Some("pong"),
      _ => None,
    }
  }
}

// 内置插件示例: 回声插件
struct EchoPlugin {
  prefix: String
}

fn EchoPlugin::new(prefix: String) -> EchoPlugin {
  EchoPlugin::{ prefix: prefix }
}

impl Plugin for EchoPlugin {
  fn meta(self: Self) -> PluginMeta {
    PluginMeta::{
      name: "echo",
      version: "1.0.0",
      author: "Deep Sea Team",
      description: "Echo messages back with prefix",
      dependencies: [],
    }
  }
  
  fn on_load(self: Self, ctx: PluginContext) -> Result[Unit] {
    Ok(())
  }
  
  fn on_enable(self: Self) -> Unit {}
  fn on_disable(self: Self) -> Unit {}
  fn on_unload(self: Self) -> Unit {}
  
  fn on_message(self: Self, msg: Message) -> Option[Response] {
    Some(Response::{
      to: msg.from,
      content: "\(self.prefix)\(msg.content)",
      channel: msg.channel,
    })
  }
}

// 内置插件示例: 计时器插件
struct TimerPlugin {
  timers: Map[String, Int]
}

fn TimerPlugin::new() -> TimerPlugin {
  TimerPlugin::{ timers: Map::new() }
}

impl Plugin for TimerPlugin {
  fn meta(self: Self) -> PluginMeta {
    PluginMeta::{
      name: "timer",
      version: "1.0.0",
      author: "Deep Sea Team",
      description: "Timer and reminder plugin",
      dependencies: [],
    }
  }
  
  fn on_load(self: Self, ctx: PluginContext) -> Result[Unit] {
    Ok(())
  }
  
  fn on_enable(self: Self) -> Unit {}
  fn on_disable(self: Self) -> Unit {}
  fn on_unload(self: Self) -> Unit {}
  
  fn on_command(self: Self, cmd: String, args: Array[String]) -> Option[String] {
    match cmd {
      "timer" => {
        if args.length() > 0 {
          let action = args[0]
          match action {
            "list" => {
              let mut result = "Timers:\n"
              for (name, time) in self.timers {
                result = "\(result)- \(name): \(time)s\n"
              }
              Some(result)
            }
            "set" => {
              if args.length() > 2 {
                let name = args[1]
                let seconds = parse_int(args[2])
                self.timers.insert(name, seconds)
                Some("Timer set: \(name) = \(seconds)s")
              } else {
                Some("Usage: timer set <name> <seconds>")
              }
            }
            _ => Some("Usage: timer [list|set]"),
          }
        } else {
          Some("Usage: timer [list|set]")
        }
      }
      _ => None,
    }
  }
}
