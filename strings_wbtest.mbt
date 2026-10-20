///|
test "strings concatenate across comments and preserve escaped bytes" {
  let r = Reader::new(
    b"\"a\\xFF\" /* glue */ \"\\n\\t\\a\\b\\f\\r\\v\\\\\\\"\"",
    Limits::default(),
  )
  assert_eq(r.text(), b"a\xff\n\t\x07\x08\x0c\r\x0b\\\"")
}

///|
test "invalid and unterminated escapes are rejected" {
  for input in [b"\"\\u1234\"", b"\"\\xF\"", b"\"\\xGG\"", b"\"missing"] {
    let r = Reader::new(input, Limits::default())
    let rejected = try {
      ignore(r.text())
      false
    } catch {
      ConfigError(_) => true
    }
    assert_true(rejected)
  }
}

///|
test "concatenated string limit counts decoded bytes" {
  let limits = { ..Limits::default(), max_string: 2, }
  let r = Reader::new(b"\"ab\" \"c\"", limits)
  let rejected = try {
    ignore(r.text())
    false
  } catch {
    ConfigError(d) => d.code == "string_limit"
  }
  assert_true(rejected)
}
