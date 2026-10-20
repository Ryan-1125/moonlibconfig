///|
test "public path APIs enforce the documented segment bound" {
  let parts : Array[String] = []
  let segments : Array[Segment] = []
  while parts.length() < 256 {
    parts.push("a")
    segments.push(Key("a"))
  }
  assert_eq(parse_path(parts.join(".")).length(), 256)
  parts.push("a")
  segments.push(Key("a"))
  let parse_code = try {
    ignore(parse_path(parts.join(".")))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  let replace_code = try {
    ignore(Value::Group([]).replaced(segments, Integer(1)))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(parse_code, "path_limit")
  assert_eq(replace_code, "path_limit")
  let query_code = try {
    ignore(Value::Group([]).get_path(segments))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(query_code, "path_limit")
}

///|
test "writer rejects cyclic caller constructed trees within depth budget" {
  let items : Array[(String, Value)] = []
  let root = Value::Group(items)
  items.push(("loop", root))
  let code = try {
    ignore(stringify(root, limits={ ..Limits::default(), max_depth: 8, }))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "depth_limit")
}
