///|
test "comments and byte locations" {
  let r = Reader::new(b"# one\n// two\n/* three\n */answer", Limits::default())
  r.skip()
  assert_eq(r.line, 4)
  assert_eq(r.column, 4)
  assert_eq(r.name(), "answer")
  assert_eq(r.peek(), -1)
}

///|
test "unterminated block comment is an error" {
  let r = Reader::new(b"/*", Limits::default())
  let rejected = try {
    r.skip()
    false
  } catch {
    ConfigError(d) => d.code == "unterminated_comment" && d.offset == 2
  }
  assert_true(rejected)
}
