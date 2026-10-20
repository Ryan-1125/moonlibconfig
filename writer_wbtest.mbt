///|
test "fixed normalized output and byte preservation" {
  let value = parse_bytes(
    b"long=1L flag=TRUE bytes=\"\\xFF\\n\" arr=[1,2] empty=()",
  )
  let text = stringify(value)
  assert_eq(
    text, "long = 1L;\nflag = true;\nbytes = \"\\xFF\\x0A\";\narr = [1, 2];\nempty = ();\n",
  )
  assert_eq(parse(text), value)
}

///|
test "writer rejects manually constructed invalid configurations" {
  for
    root in [
      Integer(1),
      Group([("_x", Integer(1))]),
      Group([("a", Integer(1)), ("a", Integer(2))]),
      Group([("a", ScalarArray([Integer(1), Integer64(1L)]))]),
      Group([("a", ScalarArray([List([])]))]),
      Group([("a", Float(1.0 / 0.0))]),
    ] {
    let rejected = try {
      ignore(stringify(root))
      false
    } catch {
      ConfigError(_) => true
    }
    assert_true(rejected)
  }
}

///|
test "floating point output retains type including integral values" {
  let root = Group([
    ("a", Float(1.0)),
    ("b", Float(-0.0)),
    ("c", Float(1.2345678901234567)),
  ])
  assert_eq(parse(stringify(root)), root)
  assert_true(
    parse(stringify(root)).lookup("b").as_double().reinterpret_as_int64() < 0L,
  )
}
