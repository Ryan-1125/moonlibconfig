///|
/// A typed path avoids ambiguity between named members and indices.
pub(all) enum Segment {
  Key(String)
  Index(Int32)
} derive(Debug, Eq)

///|
/// Parse paths such as server.port, peers[0].host or peers.[0].host.
pub fn parse_path(path : String) -> Array[Segment] raise ConfigError {
  if path.length() > Limits::default().max_input {
    raise failure("input_limit", "path exceeds byte limit")
  }
  let r = Reader::new(@utf8.encode(path), Limits::default())
  let result : Array[Segment] = []
  while r.peek() != -1 {
    if result.length() >= 256 {
      raise r.error("path_limit", "path exceeds 256 segments")
    }
    if r.peek() == 91 {
      r.advance()
      let start = r.pos
      while digit(r.peek()) {
        r.advance()
      }
      if start == r.pos || r.peek() != 93 {
        raise r.error("invalid_path", "expected nonnegative index and ]")
      }
      let index = @string.parse_int(@utf8.decode_lossy(r.data[start:r.pos])) catch {
        _ => raise r.error("invalid_path", "index exceeds 32-bit range")
      }
      result.push(Index(index))
      r.advance()
    } else {
      if !name_start(r.peek()) {
        raise r.error("invalid_path", "expected member name")
      }
      result.push(Key(r.name()))
    }
    if r.peek() == 46 {
      r.advance()
      if r.peek() == -1 {
        raise r.error("invalid_path", "trailing dot")
      }
    } else if r.peek() != -1 && r.peek() != 91 {
      raise r.error("invalid_path", "expected dot or index")
    }
  }
  result
}

///|
/// Retrieve a group member without implicit conversion.
pub fn Value::get_member(
  self : Value,
  name : String,
) -> Value raise ConfigError {
  guard self is Group(items) else {
    raise failure("type_mismatch", "expected group")
  }
  for (key, value) in items {
    if key == name {
      return value
    }
  }
  raise failure("missing_member", "missing setting: " + name)
}

///|
/// Retrieve an array/list element. Negative indices are errors.
pub fn Value::at(self : Value, index : Int32) -> Value raise ConfigError {
  let items = match self {
    ScalarArray(v) | List(v) => v
    _ => raise failure("type_mismatch", "expected array or list")
  }
  match items.get(index) {
    Some(v) => v
    None => raise failure("index_out_of_bounds", "index outside container")
  }
}

///|
/// Look up a typed path. An empty path addresses the root.
pub fn Value::get_path(
  self : Value,
  path : ArrayView[Segment],
) -> Value raise ConfigError {
  if path.length() > 256 {
    raise failure("path_limit", "query path exceeds 256 segments")
  }
  let mut value = self
  for part in path {
    value = match part {
      Key(name) => value.get_member(name)
      Index(i) => value.at(i)
    }
  }
  value
}

///|
/// Look up a dot/bracket path.
pub fn Value::lookup(self : Value, path : String) -> Value raise ConfigError {
  self.get_path(parse_path(path))
}

///|
/// Strict 32-bit extraction.
pub fn Value::as_int(self : Value) -> Int32 raise ConfigError {
  match self {
    Integer(v) => v
    _ => raise failure("type_mismatch", "expected integer")
  }
}

///|
/// Strict 64-bit extraction (does not widen Integer automatically).
pub fn Value::as_int64(self : Value) -> Int64 raise ConfigError {
  match self {
    Integer64(v) => v
    _ => raise failure("type_mismatch", "expected integer64")
  }
}

///|
/// Strict floating point extraction.
pub fn Value::as_double(self : Value) -> Double raise ConfigError {
  match self {
    Float(v) => v
    _ => raise failure("type_mismatch", "expected float")
  }
}

///|
/// Strict boolean extraction.
pub fn Value::as_bool(self : Value) -> Bool raise ConfigError {
  match self {
    Boolean(v) => v
    _ => raise failure("type_mismatch", "expected boolean")
  }
}

///|
/// Strict byte string extraction, without UTF-8 decoding.
pub fn Value::as_bytes(self : Value) -> Bytes raise ConfigError {
  match self {
    Text(v) => v
    _ => raise failure("type_mismatch", "expected string")
  }
}

///|
/// Return a tree with an existing setting replaced, leaving source containers unchanged.
pub fn Value::replaced(
  self : Value,
  path : ArrayView[Segment],
  replacement : Value,
) -> Value raise ConfigError {
  if path.length() > 256 {
    raise failure("path_limit", "replacement path exceeds 256 segments")
  }
  if path.length() == 0 {
    return replacement
  }
  match path[0] {
    Key(name) => {
      guard self is Group(items) else {
        raise failure("type_mismatch", "expected group")
      }
      let output = items.copy()
      for i = 0; i < output.length(); i = i + 1 {
        let (key, value) = output[i]
        if key == name {
          output[i] = (key, value.replaced(path[1:], replacement))
          return Group(output)
        }
      }
      raise failure("missing_member", "missing setting: " + name)
    }
    Index(index) => {
      let old = self.at(index)
      let changed = old.replaced(path[1:], replacement)
      match self {
        ScalarArray(items) => {
          if changed.kind() != old.kind() {
            raise failure(
              "array_type", "replacement changes array element type",
            )
          }
          let output = items.copy()
          output[index] = changed
          ScalarArray(output)
        }
        List(items) => {
          let output = items.copy()
          output[index] = changed
          List(output)
        }
        _ => raise failure("type_mismatch", "expected array or list")
      }
    }
  }
}
