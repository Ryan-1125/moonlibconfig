///|
test "nested service configuration has fixed expected tree" {
  let config = parse(
    "name = \"Moon\"; server: { port = 9000; enabled = True }; peers = ( { host = \"a\" }, { host = \"b\" }, ); sizes = [1L, 2L,];",
  )
  assert_eq(
    config,
    Group([
      ("name", Text(b"Moon")),
      ("server", Group([("port", Integer(9000)), ("enabled", Boolean(true))])),
      (
        "peers",
        List([Group([("host", Text(b"a"))]), Group([("host", Text(b"b"))])]),
      ),
      ("sizes", ScalarArray([Integer64(1L), Integer64(2L)])),
    ]),
  )
}

///|
test "invalid structure cannot return partial success" {
  for
    input in [
      "x=1; x=2;", "x=[1,2L]", "x=[{}]", "x=(1 2)", "x={", "x=1; }", "x=", "_bad=1",
      "x=1;;", "x=1; rubbish", "@include \"secret\"", "x={ @include \"a\" }",
    ] {
    let rejected = try {
      ignore(parse(input))
      false
    } catch {
      ConfigError(_) => true
    }
    assert_true(rejected)
  }
}

///|
test "all empty container kinds and semicolon free syntax" {
  assert_eq(
    parse("a={} b=[] c=()"),
    Group([("a", Group([])), ("b", ScalarArray([])), ("c", List([]))]),
  )
}
