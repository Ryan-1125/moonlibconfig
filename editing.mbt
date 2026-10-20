///|
/// Return a group with a member inserted or replaced. Existing order is retained;
/// new names append at the end. Unchanged values are shared with the source.
pub fn Value::with_member(
  self : Value,
  name : String,
  value : Value,
) -> Value raise ConfigError {
  guard self is Group(items) else {
    raise failure("type_mismatch", "expected group")
  }
  check_name(name)
  let output = items.copy()
  for i = 0; i < output.length(); i = i + 1 {
    if output[i].0 == name {
      output[i] = (name, value)
      return Group(output)
    }
  }
  output.push((name, value))
  Group(output)
}

///|
/// Return a group without an existing member; missing names are errors.
/// Unchanged values are shared; no source container is modified.
pub fn Value::without_member(
  self : Value,
  name : String,
) -> Value raise ConfigError {
  guard self is Group(items) else {
    raise failure("type_mismatch", "expected group")
  }
  let output : Array[(String, Value)] = []
  let mut found = false
  for (key, value) in items {
    if key == name {
      found = true
    } else {
      output.push((key, value))
    }
  }
  if !found {
    raise failure("missing_member", "missing setting: " + name)
  }
  Group(output)
}

///|
fn check_name(name : String) -> Unit raise ConfigError {
  let bytes = @utf8.encode(name)
  if bytes.is_empty() || !name_start(bytes[0].to_int()) {
    raise failure("invalid_name", "invalid setting name")
  }
  for b in bytes {
    if !name_part(b.to_int()) {
      raise failure("invalid_name", "invalid setting name")
    }
  }
}
