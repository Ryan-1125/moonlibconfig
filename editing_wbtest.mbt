///|
test "group edits preserve ordering and original containers" {
  let source = parse("a=1 b=2")
  let added = source.with_member("c", Integer64(3L))
  let replaced = added.with_member("a", Boolean(true))
  let removed = replaced.without_member("b")
  assert_eq(removed, Group([("a", Boolean(true)), ("c", Integer64(3L))]))
  assert_eq(source, Group([("a", Integer(1)), ("b", Integer(2))]))
  assert_eq(parse(stringify(removed)), removed)
  assert_eq(
    Value::Group([])
    .with_member("*valid-name_1", Integer(0))
    .get_member("*valid-name_1"),
    Integer(0),
  )
}

///|
test "group edit errors distinguish invalid names types and missing members" {
  for name in ["", "_bad", "has.dot", "月", "0bad", "has space"] {
    let code = try {
      ignore(Value::Group([]).with_member(name, Integer(1)))
      "accepted"
    } catch {
      ConfigError(d) => d.code
    }
    assert_eq(code, "invalid_name")
  }
  let missing = try {
    ignore(Value::Group([]).without_member("none"))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(missing, "missing_member")
  for value in [Integer(1), ScalarArray([]), List([])] {
    let add = try {
      ignore(value.with_member("a", Integer(1)))
      "accepted"
    } catch {
      ConfigError(d) => d.code
    }
    let remove = try {
      ignore(value.without_member("a"))
      "accepted"
    } catch {
      ConfigError(d) => d.code
    }
    assert_eq(add, "type_mismatch")
    assert_eq(remove, "type_mismatch")
  }
}

///|
test "nested group edits compose with path replacement" {
  let source = parse("service={port=9000 old=false}")
  let service = source
    .lookup("service")
    .with_member("enabled", Boolean(true))
    .without_member("old")
  let output = source.replaced(parse_path("service"), service)
  assert_true(output.lookup("service.enabled").as_bool())
  assert_eq(output.lookup("service.port").as_int(), 9000)
  assert_eq(source.lookup("service.old").as_bool(), false)
  assert_eq(parse(stringify(output)), output)
}
