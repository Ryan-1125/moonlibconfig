///|
test "string extraction preserves leading UTF-8 BOM as value data" {
  let bytes = b"\xef\xbb\xbfhello"
  let value = Value::Text(bytes)
  assert_eq(@utf8.encode(value.as_string()), bytes)
  let parsed = parse_bytes(b"s=\"\\xEF\\xBB\\xBFhello\"")
  assert_eq(@utf8.encode(parsed.lookup("s").as_string()), bytes)
  assert_eq(
    @utf8.encode(Value::Text(b"\xef\xbb\xbf").as_string()),
    b"\xef\xbb\xbf",
  )
  assert_eq(parse(stringify(parsed)), parsed)
}
