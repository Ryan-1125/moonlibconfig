///|
test "submission contract for include rejection and eight differential cases" {
  for input in ["@include \"child.cfg\"", "a={@include \"child.cfg\"}"] {
    let code = try {
      ignore(parse(input))
      "accepted"
    } catch {
      ConfigError(d) => d.code
    }
    assert_eq(code, "unsupported_include")
  }
  for
    input in [
      "a=1 /*", "a=\"\\u1234\"", "a=\"\\xG0\"", "a=\"\\x0\"", "a=\"\\x00after\"",
      "a=1e999",
    ] {
    let rejected = try {
      ignore(parse(input))
      false
    } catch {
      ConfigError(_) => true
    }
    assert_true(rejected)
  }
  for
    (input, expected) in [
      ("a=0xFFFFFFFFL", 4294967295L),
      ("a=0xffffffffffffffff", -1L),
    ] {
    let tree = parse(input)
    assert_eq(tree.lookup("a").as_int64(), expected)
    assert_eq(parse(stringify(tree)), tree)
  }
}
