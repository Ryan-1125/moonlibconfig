///|
fn parse_error(input : Bytes, limits : Limits) -> String {
  try {
    ignore(parse_bytes(input, limits~))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
}

///|
test "input limits are byte based with exact boundaries" {
  assert_eq(
    parse_error(b"a=1", { ..Limits::default(), max_input: 3, }),
    "accepted",
  )
  assert_eq(
    parse_error(b"a=1 ", { ..Limits::default(), max_input: 3, }),
    "input_limit",
  )
  assert_eq(
    parse_error(@utf8.encode("a=\"月\""), {
      ..Limits::default(),
      max_input: 6,
    }),
    "input_limit",
  )
}

///|
test "depth and node limits exclude the root" {
  assert_eq(
    parse_error(b"a=1", { ..Limits::default(), max_depth: 0, }),
    "accepted",
  )
  assert_eq(
    parse_error(b"a=[]", { ..Limits::default(), max_depth: 0, }),
    "depth_limit",
  )
  assert_eq(
    parse_error(b"a=()", { ..Limits::default(), max_depth: 1, }),
    "accepted",
  )
  assert_eq(
    parse_error(b"a=(())", { ..Limits::default(), max_depth: 1, }),
    "depth_limit",
  )
  assert_eq(
    parse_error(b"a=(1)", { ..Limits::default(), max_nodes: 2, }),
    "accepted",
  )
  assert_eq(
    parse_error(b"a=(1)", { ..Limits::default(), max_nodes: 1, }),
    "node_limit",
  )
  assert_eq(
    parse_error(b"", { ..Limits::default(), max_nodes: 0, }),
    "accepted",
  )
}

///|
test "string and option boundaries" {
  assert_eq(
    parse_error(b"a=\"\\xFF\"", { ..Limits::default(), max_string: 1, }),
    "accepted",
  )
  assert_eq(
    parse_error(b"a=\"ab\"", { ..Limits::default(), max_string: 1, }),
    "string_limit",
  )
  assert_eq(
    parse_error(b"a=\"\"", { ..Limits::default(), max_string: 0, }),
    "accepted",
  )
  for
    limits in [
      { ..Limits::default(), max_input: -1, },
      { ..Limits::default(), max_depth: 257, },
      { ..Limits::default(), max_nodes: -1, },
      { ..Limits::default(), max_string: -1, },
    ] {
    assert_eq(parse_error(b"", limits), "invalid_limits")
  }
}

///|
test "diagnostic line and byte column survive UTF-8 and CRLF" {
  let diagnostic = try {
    ignore(parse("a=\"月\"\r\n b=[1, true]"))
    None
  } catch {
    ConfigError(d) => Some(d)
  }
  guard diagnostic is Some(d) else { fail("expected mixed-array error") }
  assert_eq(d.code, "array_type")
  assert_eq(d.line, 2)
  assert_eq(d.column, 12)
}

///|
test "writer obeys exact output and tree limits" {
  let root = parse("a=1")
  assert_eq(
    stringify(root, limits={ ..Limits::default(), max_input: 7, }),
    "a = 1;\n",
  )
  let code = try {
    ignore(stringify(root, limits={ ..Limits::default(), max_input: 6, }))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "output_limit")
  let root = parse("a=(1)")
  let code = try {
    ignore(stringify(root, limits={ ..Limits::default(), max_nodes: 1, }))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "node_limit")
}

///|
test "every non-NUL byte survives canonical string serialization" {
  let bytes = Bytes::makei(255, i => (i + 1).to_byte())
  let root = Group([("all", Text(bytes))])
  assert_eq(parse(stringify(root)), root)
}

///|
test "NUL is explicitly rejected rather than silently truncated" {
  assert_eq(
    parse_error(b"a=\"\\x00tail\"", Limits::default()),
    "unsupported_nul",
  )
  let code = try {
    ignore(stringify(Group([("a", Text(b"\x00tail"))])))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "unsupported_nul")
}

///|
test "truncated inputs and nested malformed syntax fail finitely" {
  let input = b"a={b=(\"hello\",[1,2],{c=false})}"
  // Every proper prefix after a= and before the last brace is incomplete.
  for size = 2; size < input.length(); size = size + 1 {
    let prefix = input[0:size].to_owned()
    assert_true(parse_error(prefix, Limits::default()) != "accepted")
  }
}
