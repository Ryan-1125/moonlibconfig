///|
/// A typed libconfig value. Text stores bytes, including non-UTF-8 escapes.
pub(all) enum Value {
  Integer(Int32)
  Integer64(Int64)
  Float(Double)
  Boolean(Bool)
  Text(Bytes)
  Group(Array[(String, Value)])
  ScalarArray(Array[Value])
  List(Array[Value])
} derive(Debug, Eq)

///|
/// Resource limits count input/string bytes and value nodes (excluding root).
pub(all) struct Limits {
  max_input : Int32
  max_depth : Int32
  max_nodes : Int32
  max_string : Int32
} derive(Debug, Eq)

///|
/// Conservative defaults for in-memory configuration files.
pub fn Limits::default() -> Limits {
  { max_input: 1048576, max_depth: 64, max_nodes: 100000, max_string: 262144, }
}

///|
/// Locations are one-based lines/byte-columns; offset is zero-based bytes.
pub(all) struct Diagnostic {
  code : String
  message : String
  offset : Int32
  line : Int32
  column : Int32
} derive(Debug, Eq)

///|
/// Parsing, access and writing errors share a structured diagnostic.
pub suberror ConfigError {
  ConfigError(Diagnostic)
} derive(Debug)

///|
/// Stable type names; array element checking uses the exact scalar type.
pub fn Value::kind(self : Value) -> String {
  match self {
    Integer(_) => "integer"
    Integer64(_) => "integer64"
    Float(_) => "float"
    Boolean(_) => "boolean"
    Text(_) => "string"
    Group(_) => "group"
    ScalarArray(_) => "array"
    List(_) => "list"
  }
}

///|
fn failure(code : String, message : String) -> ConfigError {
  ConfigError({ code, message, offset: 0, line: 1, column: 1, })
}

///|
/// Strict UTF-8 extraction; escaped arbitrary bytes may fail decoding.
pub fn Value::as_string(self : Value) -> String raise ConfigError {
  guard self is Text(bytes) else {
    raise failure("type_mismatch", "expected string")
  }
  @utf8.decode(bytes) catch {
    _ => raise failure("invalid_utf8", "string contains invalid UTF-8 bytes")
  }
}
