///|
/// Parse UTF-8 text. Include directives are explicitly unsupported.
pub fn parse(
  input : String,
  limits~ : Limits = Limits::default(),
) -> Value raise ConfigError {
  // UTF-16 length is a cheap lower bound before UTF-8 allocation.
  if input.length() > limits.max_input && limits.max_input >= 0 {
    raise failure("input_limit", "input exceeds byte limit")
  }
  parse_bytes(@utf8.encode(input), limits~)
}

///|
/// Parse libconfig bytes; returned root is always a Group.
pub fn parse_bytes(
  input : Bytes,
  limits~ : Limits = Limits::default(),
) -> Value raise ConfigError {
  let reader = Reader::new(input, limits)
  Group(reader.settings(0, -1))
}

///|
fn Reader::settings(
  self : Reader,
  depth : Int32,
  closing : Int32,
) -> Array[(String, Value)] raise ConfigError {
  let items : Array[(String, Value)] = []
  let names : Map[String, Bool] = Map([])
  self.skip()
  while self.peek() != closing {
    if self.peek() == 64 {
      raise self.error(
        "unsupported_include", "include directives require an external preprocessor",
      )
    }
    if self.peek() == -1 {
      raise self.error("unexpected_eof", "unclosed group")
    }
    let name = self.name()
    if names.contains(name) {
      raise self.error("duplicate_name", "duplicate setting: " + name)
    }
    names[name] = true
    self.skip()
    if self.peek() != 61 && self.peek() != 58 {
      raise self.error("unexpected_token", "expected = or :")
    }
    self.advance()
    let value = self.value(depth)
    items.push((name, value))
    self.skip()
    if self.peek() == 59 {
      self.advance()
      self.skip()
    }
  }
  if closing != -1 {
    self.advance()
  }
  items
}

///|
fn Reader::value(self : Reader, depth : Int32) -> Value raise ConfigError {
  self.skip()
  if self.nodes >= self.limits.max_nodes {
    raise self.error("node_limit", "value count exceeds limit")
  }
  self.nodes += 1
  let c = self.peek()
  if c == 64 {
    raise self.error(
      "unsupported_include", "include directives are not supported",
    )
  }
  if c == 34 {
    return Text(self.text())
  }
  if c == 123 || c == 91 || c == 40 {
    if depth >= self.limits.max_depth {
      raise self.error("depth_limit", "container nesting exceeds limit")
    }
    self.advance()
    if c == 123 {
      return Group(self.settings(depth + 1, 125))
    }
    let close = if c == 91 { 93 } else { 41 }
    let values : Array[Value] = []
    self.skip()
    while self.peek() != close {
      if c == 91 &&
        (self.peek() == 123 || self.peek() == 91 || self.peek() == 40) {
        raise self.error("array_type", "array elements must be scalars")
      }
      let v = self.value(depth + 1)
      if c == 91 && values.length() > 0 && values[0].kind() != v.kind() {
        raise self.error(
          "array_type", "array elements must have the same scalar type",
        )
      }
      values.push(v)
      self.skip()
      if self.peek() == close {
        break
      }
      self.expect(44)
      self.skip()
    }
    self.expect(close)
    if c == 91 {
      ScalarArray(values)
    } else {
      List(values)
    }
  } else {
    self.atom()
  }
}
