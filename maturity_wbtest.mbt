///|
test "container edits retain kinds order and source values" {
  let source = ScalarArray([Integer(1), Integer(3)])
  let edited = source.inserted(1, Integer(2)).appended(Integer(4)).removed_at(0)
  assert_eq(edited, ScalarArray([Integer(2), Integer(3), Integer(4)]))
  assert_eq(source, ScalarArray([Integer(1), Integer(3)]))
  assert_eq(
    List([]).appended(Group([])).inserted(0, Boolean(true)),
    List([Boolean(true), Group([])]),
  )
  assert_eq(ScalarArray([Integer(1)]).removed_at(0), ScalarArray([]))
  assert_eq(
    ScalarArray([]).appended(Integer64(1L)),
    ScalarArray([Integer64(1L)]),
  )
}

///|
test "container edits reject bounds types and mixed array widths" {
  for i in [-1, 2] {
    let code = try {
      ignore(List([]).inserted(i, Integer(1)))
      "accepted"
    } catch {
      ConfigError(d) => d.code
    }
    assert_eq(code, "index_out_of_bounds")
    let code = try {
      ignore(List([]).removed_at(i))
      "accepted"
    } catch {
      ConfigError(d) => d.code
    }
    assert_eq(code, "index_out_of_bounds")
  }
  for v in [Integer64(1L), Group([]), List([]), ScalarArray([])] {
    let code = try {
      ignore(ScalarArray([Integer(1)]).appended(v))
      "accepted"
    } catch {
      ConfigError(d) => d.code
    }
    assert_eq(code, "array_type")
  }
  let code = try {
    ignore(Integer(1).appended(Integer(2)))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "type_mismatch")
}

///|
test "independent validation accepts values without output allocation" {
  let root = parse("a={b=(1,2L,true,[1,2])} s=\"hello\"")
  assert_eq(validate(root), [])
  // A semantic validator has no serialized-output budget.
  assert_eq(validate(root, limits={ ..Limits::default(), max_input: 0, }), [])
  assert_eq(validate(Integer(1))[0].code, "type_mismatch")
}

///|
test "validation aggregates independent issues with specific paths" {
  let root = Group([
    ("dup", Integer(1)),
    ("dup", Integer(2)),
    ("_bad", Integer(1)),
    ("a", ScalarArray([Integer(1), Integer64(2L)])),
    ("s", Text(b"a\x00b")),
    ("f", Float(1.0 / 0.0)),
  ])
  let issues = validate(root)
  assert_eq(issues.map(i => (i.path, i.code)), [
    ("dup", "duplicate_name"),
    ("_bad", "invalid_name"),
    ("a[1]", "array_type"),
    ("s", "unsupported_nul"),
    ("f", "non_finite_float"),
  ])
  assert_true(issues[2].message.contains("integer64"))
}

///|
test "validation budgets stop cycles and bound traversal" {
  let items : Array[(String, Value)] = []
  let cycle = Group(items)
  items.push(("cycle", cycle))
  let issues = validate(cycle, limits={ ..Limits::default(), max_depth: 2, })
  assert_eq(issues.length(), 1)
  assert_eq(issues[0].path, "cycle.cycle.cycle")
  assert_eq(issues[0].code, "depth_limit")
  let issues = validate(parse("a=(1,2,3) b=1"), limits={
    ..Limits::default(),
    max_nodes: 2,
  })
  assert_eq(issues.length(), 1)
  assert_eq(issues[0].path, "a[1]")
  assert_eq(issues[0].code, "node_limit")
  assert_eq(
    validate(Group([("s", Text(b"ab"))]), limits={
      ..Limits::default(),
      max_string: 1,
    })[0].code,
    "string_limit",
  )
  let code = try {
    ignore(validate(Group([]), limits={ ..Limits::default(), max_depth: 257, }))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "invalid_limits")
}

///|
test "documents record setting and value starts in byte coordinates" {
  let doc = parse_document("# first\r\na={\n b=\"月\";\n c=(1, 2L)\n}")
  assert_eq(doc.root(), parse("a={b=\"月\";c=(1,2L)}"))
  guard doc.location("a.b") is Some(b) else { fail("missing location") }
  assert_eq((b.setting.line, b.setting.column), (3, 2))
  assert_eq((b.value.line, b.value.column), (3, 4))
  assert_eq(doc.location("a.c[1]"), doc.location("a.c.[1]"))
  guard doc.location("a.c[1]") is Some(element) else { fail("missing element") }
  assert_eq((element.value.line, element.value.column), (4, 8))
  assert_eq(doc.location("absent"), None)
  guard parse_document("a=\"月\"; b=1").location("b") is Some(after_unicode) else {
    fail("missing location")
  }
  assert_eq(
    (after_unicode.setting.column, after_unicode.value.column),
    (10, 12),
  )
}

///|
test "document typed queries report actual type and original value position" {
  let doc = parse_document("a={\n port=\"9000\"\n}")
  let diagnostic = try {
    ignore(doc.get_int("a.port"))
    None
  } catch {
    ConfigError(d) => Some(d)
  }
  guard diagnostic is Some(d) else { fail("expected type mismatch") }
  assert_eq(d.code, "type_mismatch")
  assert_eq((d.line, d.column), (2, 7))
  assert_true(
    d.message.contains("a.port") &&
    d.message.contains("expected integer") &&
    d.message.contains("actual string"),
  )
  let missing = try {
    ignore(doc.lookup("a.none"))
    None
  } catch {
    ConfigError(d) => Some(d)
  }
  guard missing is Some(m) else { fail("expected missing member") }
  assert_eq((m.line, m.column), (1, 3))
  assert_true(m.message.contains("a.none"))
}

///|
test "document scalar queries and byte decoding preserve strict semantics" {
  let doc = parse_document_bytes(
    b"i=1 l=2L f=1.5 b=true s=\"hi\" invalid=\"\\xFF\"",
  )
  assert_eq(doc.get_int("i"), 1)
  assert_eq(doc.get_int64("l"), 2L)
  assert_eq(doc.get_double("f"), 1.5)
  assert_true(doc.get_bool("b"))
  assert_eq(doc.get_string("s"), "hi")
  assert_eq(doc.get_bytes("invalid"), b"\xff")
  let d = try {
    ignore(doc.get_string("invalid"))
    None
  } catch {
    ConfigError(d) => Some(d)
  }
  guard d is Some(d) else { fail("expected decoding failure") }
  assert_eq(d.code, "invalid_utf8")
  assert_true(d.offset > 0 && d.message.contains("invalid"))
}

///|
test "document parse errors and input limits retain paths and byte limits" {
  let d = try {
    ignore(parse_document("a={b=@include \"x\"}"))
    None
  } catch {
    ConfigError(d) => Some(d)
  }
  guard d is Some(d) else { fail("expected include error") }
  assert_eq(d.code, "unsupported_include")
  assert_true(d.message.contains("a.b"))
  let code = try {
    ignore(parse_document("a=1", limits={ ..Limits::default(), max_input: 2, }))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "input_limit")
}
