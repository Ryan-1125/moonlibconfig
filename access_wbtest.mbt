///|
test "lookup and replacement of nested service values" {
  let root = parse("server={port=9000} peers=({host=\"one\"},{host=\"two\"})")
  assert_eq(root.lookup("peers.[1].host").as_string(), "two")
  assert_eq(root.lookup("peers[0].host").as_bytes(), b"one")
  let changed = root.replaced(parse_path("server.port"), Integer(8080))
  assert_eq(changed.lookup("server.port").as_int(), 8080)
  assert_eq(root.lookup("server.port").as_int(), 9000)
  assert_eq(root.lookup(""), root)
}

///|
test "path syntax and strict extraction errors" {
  for path in ["a.", "a..b", "a[-1]", "a[]", "a[999999999999]", "a[0]b", ".a"] {
    let rejected = try {
      ignore(parse_path(path))
      false
    } catch {
      ConfigError(_) => true
    }
    assert_true(rejected)
  }
  let root = parse("a=[1,2]")
  let width = try {
    ignore(root.lookup("a[0]").as_int64())
    false
  } catch {
    ConfigError(d) => d.code == "type_mismatch"
  }
  let missing = try {
    ignore(root.lookup("missing"))
    false
  } catch {
    ConfigError(d) => d.code == "missing_member"
  }
  let bounds = try {
    ignore(root.lookup("a[2]"))
    false
  } catch {
    ConfigError(d) => d.code == "index_out_of_bounds"
  }
  assert_true(width && missing && bounds)
}
