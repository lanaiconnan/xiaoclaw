// XiaoClaw 轻量级优化模块
// 延迟加载、对象池、零拷贝优化

// 懒加载值
struct Lazy[T] {
  value: T?
  init_fn: () -> T
  initialized: Bool
}

fn Lazy::new(init_fn: () -> T) -> Lazy[T] {
  Lazy::{
    value: None,
    init_fn: init_fn,
    initialized: false,
  }
}

fn Lazy::get(self: Lazy[T]) -> T {
  if !self.initialized {
    self.value = Some(self.init_fn())
    self.initialized = true
  }
  
  match self.value {
    Some(v) => v,
    None => self.init_fn(),  // fallback
  }
}

fn Lazy::is_loaded(self: Lazy[T]) -> Bool {
  self.initialized
}

// 延迟初始化器
struct LazyInit {
  initialized: Bool
  init_fn: () -> Unit
}

fn LazyInit::new(init_fn: () -> Unit) -> LazyInit {
  LazyInit::{
    initialized: false,
    init_fn: init_fn,
  }
}

fn LazyInit::init(self: LazyInit) -> Unit {
  if !self.initialized {
    self.init_fn()
    self.initialized = true
  }
}

// 对象池
struct ObjectPool[T] {
  available: Array[T]
  in_use: Int
  max_size: Int
  factory: () -> T
  reset_fn: (T) -> Unit
}

fn ObjectPool::new(max_size: Int, factory: () -> T, reset_fn: (T) -> Unit) -> ObjectPool[T] {
  ObjectPool::{
    available: [],
    in_use: 0,
    max_size: max_size,
    factory: factory,
    reset_fn: reset_fn,
  }
}

fn ObjectPool::acquire(self: ObjectPool[T]) -> T {
  if self.available.length() > 0 {
    self.in_use = self.in_use + 1
    self.available.pop()
  } else {
    self.in_use = self.in_use + 1
    self.factory()
  }
}

fn ObjectPool::release(self: ObjectPool[T], obj: T) -> Unit {
  self.reset_fn(obj)
  self.in_use = self.in_use - 1
  self.available.push(obj)
}

fn ObjectPool::size(self: ObjectPool[T]) -> Int {
  self.available.length()
}

fn ObjectPool::in_use_count(self: ObjectPool[T]) -> Int {
  self.in_use
}

// 缓存
struct Cache[K, V] {
  data: Map[K, V]
  max_size: Int
  hits: Int
  misses: Int
}

fn Cache::new(max_size: Int) -> Cache[K, V] {
  Cache::{
    data: Map::new(),
    max_size: max_size,
    hits: 0,
    misses: 0,
  }
}

fn Cache::get(self: Cache[K, V], key: K) -> V? {
  match self.data.get(key) {
    Some(v) => {
      self.hits = self.hits + 1
      Some(v)
    }
    None => {
      self.misses = self.misses + 1
      None
    }
  }
}

fn Cache::set(self: Cache[K, V], key: K, value: V) -> Unit {
  if self.data.keys().length() >= self.max_size {
    // LRU: 删除第一个
    let keys = self.data.keys()
    if keys.length() > 0 {
      self.data.remove(keys[0])
    }
  }
  
  self.data.insert(key, value)
}

fn Cache::clear(self: Cache[K, V]) -> Unit {
  self.data = Map::new()
  self.hits = 0
  self.misses = 0
}

fn Cache::hit_rate(self: Cache[K, V]) -> Double {
  let total = self.hits + self.misses
  if total == 0 { 0.0 }
  else { (self.hits as Double) / (total as Double) }
}

// 零拷贝字符串视图
struct StrView {
  data: String
  start: Int
  len: Int
}

fn StrView::new(data: String) -> StrView {
  StrView::{
    data: data,
    start: 0,
    len: data.length(),
  }
}

fn StrView::substring(self: StrView, start: Int, len: Int) -> StrView {
  StrView::{
    data: self.data,
    start: self.start + start,
    len: len,
  }
}

fn StrView::to_string(self: StrView) -> String {
  self.data.substring(self.start, self.len)
}

// 小字符串优化 (SSO)
struct SmallString {
  length: Int
  data: Array[Char]  // 最大 23 字符
}

fn SmallString::new(s: String) -> SmallString {
  let chars = s.to_chars()
  SmallString::{
    length: chars.length(),
    data: chars,
  }
}

fn SmallString::to_string(self: SmallString) -> String {
  String::from_chars(self.data)
}

fn SmallString::length(self: SmallString) -> Int {
  self.length
}

// 环形缓冲区
struct RingBuffer[T] {
  data: Array[T?]
  capacity: Int
  head: Int
  tail: Int
  size: Int
}

fn RingBuffer::new(capacity: Int) -> RingBuffer[T] {
  let mut data = []
  for i in 0..capacity {
    data.push(None)
  }
  
  RingBuffer::{
    data: data,
    capacity: capacity,
    head: 0,
    tail: 0,
    size: 0,
  }
}

fn RingBuffer::push(self: RingBuffer[T], item: T) -> Bool {
  if self.size >= self.capacity {
    return false
  }
  
  self.data[self.tail] = Some(item)
  self.tail = (self.tail + 1) % self.capacity
  self.size = self.size + 1
  true
}

fn RingBuffer::pop(self: RingBuffer[T]) -> T? {
  if self.size == 0 {
    return None
  }
  
  let item = self.data[self.head]
  self.data[self.head] = None
  self.head = (self.head + 1) % self.capacity
  self.size = self.size - 1
  item
}

fn RingBuffer::is_empty(self: RingBuffer[T]) -> Bool {
  self.size == 0
}

fn RingBuffer::is_full(self: RingBuffer[T]) -> Bool {
  self.size >= self.capacity
}
