///|
priv struct Reader {
  data : Bytes
  limits : Limits
  mut pos : Int32
  mut line : Int32
  mut column : Int32
  mut nodes : Int32
  mut trace : Bool
  locations : Map[String, SourceLocation]
  mut current_path : String
}

///|
fn Reader::new(data : Bytes, limits : Limits) -> Reader raise ConfigError {
  if limits.max_input < 0 ||
    limits.max_depth < 0 ||
    limits.max_depth > 256 ||
    limits.max_nodes < 0 ||
    limits.max_string < 0 {
    raise failure(
      "invalid_limits", "limits must be nonnegative; max_depth must not exceed 256",
    )
  }
  if data.length() > limits.max_input {
    raise failure("input_limit", "input exceeds byte limit")
  }
  {
    data,
    limits,
    pos: 0,
    line: 1,
    column: 1,
    nodes: 0,
    trace: false,
    locations: Map([]),
    current_path: "",
  }
}

///|
fn Reader::peek(self : Reader, ahead~ : Int32 = 0) -> Int32 {
  match self.data.get(self.pos + ahead) {
    Some(b) => b.to_int()
    None => -1
  }
}

///|
fn Reader::advance(self : Reader) -> Unit {
  if self.peek() == -1 {
    return
  }
  if self.peek() == 10 {
    self.line += 1
    self.column = 1
  } else {
    self.column += 1
  }
  self.pos += 1
}

///|
fn Reader::error(self : Reader, code : String, message : String) -> ConfigError {
  ConfigError({
    code,
    message: if self.trace && self.current_path != "" {
      "at " + self.current_path + ": " + message
    } else {
      message
    },
    offset: self.pos,
    line: self.line,
    column: self.column,
  })
}

///|
fn Reader::skip(self : Reader) -> Unit raise ConfigError {
  while true {
    let c = self.peek()
    if c == 32 || c == 9 || c == 10 || c == 13 || c == 12 {
      self.advance()
    } else if c == 35 || (c == 47 && self.peek(ahead=1) == 47) {
      while self.peek() != -1 && self.peek() != 10 {
        self.advance()
      }
    } else if c == 47 && self.peek(ahead=1) == 42 {
      self.advance()
      self.advance()
      while !(self.peek() == 42 && self.peek(ahead=1) == 47) {
        if self.peek() == -1 {
          raise self.error("unterminated_comment", "expected */")
        }
        self.advance()
      }
      self.advance()
      self.advance()
    } else {
      break
    }
  }
}

///|
fn name_start(c : Int32) -> Bool {
  (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 42
}

///|
fn name_part(c : Int32) -> Bool {
  name_start(c) || (c >= 48 && c <= 57) || c == 45 || c == 95
}

///|
fn Reader::name(self : Reader) -> String raise ConfigError {
  if !name_start(self.peek()) {
    raise self.error("invalid_name", "expected ASCII setting name")
  }
  let start = self.pos
  while name_part(self.peek()) {
    self.advance()
  }
  @utf8.decode_lossy(self.data[start:self.pos])
}

///|
fn Reader::expect(self : Reader, c : Int32) -> Unit raise ConfigError {
  self.skip()
  if self.peek() != c {
    raise self.error("unexpected_token", "unexpected delimiter")
  }
  self.advance()
}
