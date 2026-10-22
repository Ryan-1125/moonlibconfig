///|
/// A zero-based byte offset and one-based line/byte-column in the original input.
pub(all) struct SourcePosition {
  offset : Int32
  line : Int32
  column : Int32
} derive(Debug, Eq)

///|
/// Starting positions of a setting name and its value. List elements use the same position.
pub(all) struct SourceLocation {
  setting : SourcePosition
  value : SourcePosition
} derive(Debug, Eq)

///|
/// Parsed values and original source locations. Locations do not follow subsequent edits.
pub struct Document {
  tree : Value
  locations : Map[String, SourceLocation]
}

///|
/// Parse UTF-8 text while preserving setting/value starting locations.
pub fn parse_document(
  input : String,
  limits~ : Limits = Limits::default(),
) -> Document raise ConfigError {
  if input.length() > limits.max_input && limits.max_input >= 0 {
    raise failure("input_limit", "input exceeds byte limit")
  }
  parse_document_bytes(@utf8.encode(input), limits~)
}

///|
/// Parse bytes with locations; no filesystem access is performed.
pub fn parse_document_bytes(
  input : Bytes,
  limits~ : Limits = Limits::default(),
) -> Document raise ConfigError {
  let reader = Reader::new(input, limits)
  reader.trace = true
  let origin = reader.position()
  reader.locations[""] = { setting: origin, value: origin, }
  let tree = Group(reader.settings(0, -1))
  { tree, locations: reader.locations, }
}

///|
/// Return the value tree. Unchanged values/containers are shared with this document.
pub fn Document::root(self : Document) -> Value {
  self.tree
}

///|
fn canonical_path(parts : ArrayView[Segment]) -> String {
  let mut path = ""
  for part in parts {
    path = match part {
      Key(name) => member_path(path, name)
      Index(i) => path + "[" + i.to_string() + "]"
    }
  }
  path
}

///|
/// Return original positions; both peers[0] and peers.[0] address the same location.
pub fn Document::location(
  self : Document,
  path : String,
) -> SourceLocation? raise ConfigError {
  self.locations.get(canonical_path(parse_path(path)))
}

///|
fn Document::annotate(
  self : Document,
  parts : ArrayView[Segment],
  d : Diagnostic,
) -> ConfigError {
  let path = canonical_path(parts)
  let mut nearest = self.locations.get("")
  for i = 1; i <= parts.length(); i = i + 1 {
    match self.locations.get(canonical_path(parts[0:i])) {
      Some(location) => nearest = Some(location)
      None => ()
    }
  }
  let position = match nearest {
    Some(location) => location.value
    None => { offset: 0, line: 1, column: 1, }
  }
  ConfigError({
    code: d.code,
    message: "at " +
    (if path == "" { "<root>" } else { path }) +
    ": " +
    d.message,
    offset: position.offset,
    line: position.line,
    column: position.column,
  })
}

///|
/// Query with source-aware errors. Missing members/indices use the nearest known parent.
pub fn Document::lookup(
  self : Document,
  path : String,
) -> Value raise ConfigError {
  let parts = parse_path(path)
  self.tree.get_path(parts) catch {
    ConfigError(d) => raise self.annotate(parts, d)
  }
}

///|
fn Document::expect(
  self : Document,
  path : String,
  kind : String,
) -> Value raise ConfigError {
  let value = self.lookup(path)
  if value.kind() != kind {
    let ConfigError(d) = failure(
      "type_mismatch",
      "expected " + kind + "; actual " + value.kind(),
    )
    raise self.annotate(parse_path(path), d)
  }
  value
}

///|
/// Strict typed queries, anchored to the original value's position.
pub fn Document::get_int(
  self : Document,
  path : String,
) -> Int32 raise ConfigError {
  self.expect(path, "integer").as_int()
}

///|
pub fn Document::get_int64(
  self : Document,
  path : String,
) -> Int64 raise ConfigError {
  self.expect(path, "integer64").as_int64()
}

///|
pub fn Document::get_double(
  self : Document,
  path : String,
) -> Double raise ConfigError {
  self.expect(path, "float").as_double()
}

///|
pub fn Document::get_bool(
  self : Document,
  path : String,
) -> Bool raise ConfigError {
  self.expect(path, "boolean").as_bool()
}

///|
pub fn Document::get_bytes(
  self : Document,
  path : String,
) -> Bytes raise ConfigError {
  self.expect(path, "string").as_bytes()
}

///|
pub fn Document::get_string(
  self : Document,
  path : String,
) -> String raise ConfigError {
  let value = self.expect(path, "string")
  value.as_string() catch {
    ConfigError(d) => raise self.annotate(parse_path(path), d)
  }
}

///|
fn Reader::position(self : Reader) -> SourcePosition {
  { offset: self.pos, line: self.line, column: self.column, }
}
