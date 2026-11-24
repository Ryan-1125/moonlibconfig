///|
test "defaults apply to absence but never conceal type or path errors" {
  let root = parse("port=9000 long=1L peers=(1)")
  assert_eq(root.lookup_optional("missing"), None)
  assert_eq(root.lookup_optional("peers[2]"), None)
  assert_eq(root.lookup_or("missing", Integer(8080)), Integer(8080))
  assert_eq(root.lookup_or("port", Integer(8080)), Integer(9000))
  for path in ["port", "long"] {
    let code = try {
      ignore(root.lookup_or(path, Boolean(false)))
      "accepted"
    } catch {
      ConfigError(d) => d.code
    }
    assert_eq(code, "type_mismatch")
  }
  let code = try {
    ignore(root.lookup_optional("port.child"))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "type_mismatch")
  let code = try {
    ignore(root.lookup_optional("bad..path"))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "invalid_path")
}
