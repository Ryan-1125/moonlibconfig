///|
test "integer widths and container kinds remain distinct" {
  assert_eq(Value::Integer(1).kind(), "integer")
  assert_eq(Value::Integer64(1L).kind(), "integer64")
  assert_eq(Value::ScalarArray([]).kind(), "array")
  assert_eq(Value::List([]).kind(), "list")
  assert_eq(Value::Group([]).kind(), "group")
}

///|
test "byte strings expose explicit UTF-8 failure" {
  assert_eq(Value::Text(b"hello").as_string(), "hello")
  let bad = try {
    ignore(Value::Text(b"\xff").as_string())
    false
  } catch {
    ConfigError(d) => d.code == "invalid_utf8"
  }
  assert_true(bad)
}
