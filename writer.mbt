///|
priv struct Writer {
  out : StringBuilder
  limits : Limits
  mut size : Int32
  mut nodes : Int32
}

///|
fn Writer::emit(self : Writer, text : String) -> Unit raise ConfigError {
  if text.length() > self.limits.max_input - self.size {
    raise failure("output_limit", "normalized output exceeds byte limit")
  }
  self.size += text.length()
  self.out.write_string(text)
}

///| Write a root group as deterministic ASCII libconfig text.

///| All non-ASCII bytes are escaped; comments and numeric bases are not preserved.

///|
/// max_input bounds the serialized output; all other limits also apply.
pub fn stringify(
  root : Value,
  limits~ : Limits = Limits::default(),
) -> String raise ConfigError {
  ignore(Reader::new(b"", limits))
  guard root is Group(items) else {
    raise failure("type_mismatch", "configuration root must be a group")
  }
  let w : Writer = { out: StringBuilder(), limits, size: 0, nodes: 0, }
  w.settings(items, 0)
  w.out.to_string()
}

///|
fn Writer::settings(
  self : Writer,
  items : Array[(String, Value)],
  depth : Int32,
) -> Unit raise ConfigError {
  let seen : Map[String, Bool] = Map([])
  for (name, value) in items {
    check_name(name)
    if seen.contains(name) {
      raise failure("duplicate_name", "duplicate setting: " + name)
    }
    seen[name] = true
    self.emit(name)
    self.emit(" = ")
    self.value(value, depth)
    self.emit(";\n")
  }
}

///|
fn Writer::value(
  self : Writer,
  value : Value,
  depth : Int32,
) -> Unit raise ConfigError {
  if self.nodes >= self.limits.max_nodes {
    raise failure("node_limit", "value count exceeds limit")
  }
  self.nodes += 1
  match value {
    Integer(v) => self.emit(v.to_string())
    Integer64(v) => {
      self.emit(v.to_string())
      self.emit("L")
    }
    Float(v) => {
      if v.is_nan() || v.is_inf() {
        raise failure("non_finite_float", "cannot serialize non-finite float")
      }
      let text = if v == 0.0 && v.reinterpret_as_int64() < 0L {
        "-0.0"
      } else {
        v.to_string()
      }
      self.emit(text)
      if !text.contains(".") && !text.contains("e") && !text.contains("E") {
        self.emit(".0")
      }
    }
    Boolean(v) => self.emit(if v { "true" } else { "false" })
    Text(bytes) => {
      if bytes.length() > self.limits.max_string {
        raise failure("string_limit", "string exceeds byte limit")
      }
      self.emit("\"")
      for b in bytes {
        let c = b.to_int()
        if c == 0 {
          raise failure(
            "unsupported_nul", "NUL bytes are not representable by libconfig string APIs",
          )
        }
        if c == 34 {
          self.emit("\\\"")
        } else if c == 92 {
          self.emit("\\\\")
        } else if c >= 32 && c <= 126 {
          self.emit(c.unsafe_to_char().to_string())
        } else {
          let digits = "0123456789ABCDEF"
          self.emit("\\x")
          self.emit(digits[c / 16:c / 16 + 1].to_owned())
          self.emit(digits[c % 16:c % 16 + 1].to_owned())
        }
      }
      self.emit("\"")
    }
    Group(items) => {
      self.check_depth(depth)
      self.emit("{\n")
      self.settings(items, depth + 1)
      self.emit("}")
    }
    ScalarArray(items) | List(items) => {
      self.check_depth(depth)
      let array = value is ScalarArray(_)
      self.emit(if array { "[" } else { "(" })
      for i = 0; i < items.length(); i = i + 1 {
        if array {
          match items[i] {
            Group(_) | ScalarArray(_) | List(_) =>
              raise failure("array_type", "array elements must be scalars")
            _ => ()
          }
          if items[i].kind() != items[0].kind() {
            raise failure("array_type", "mixed scalar array")
          }
        }
        if i > 0 {
          self.emit(", ")
        }
        self.value(items[i], depth + 1)
      }
      self.emit(if array { "]" } else { ")" })
    }
  }
}

///|
fn Writer::check_depth(self : Writer, depth : Int32) -> Unit raise ConfigError {
  if depth >= self.limits.max_depth {
    raise failure("depth_limit", "container nesting exceeds limit")
  }
}
