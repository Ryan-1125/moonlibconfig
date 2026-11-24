///|
test "target numeric interpretation follows upstream signed conversion before L" {
  let doc = parse_target(
    b"a=0xFFFFFFFFL b=0xffffffff c=0x000000001 d=0x100000000L",
  )
  assert_eq(doc.get_int64("a"), -1L)
  assert_eq(doc.get_int("b"), -1)
  assert_eq(doc.get_int("c"), 1)
  assert_eq(doc.get_int64("d"), 4294967296L)
  let code = try {
    ignore(parse_target(b"a=0xffffffffffffffff"))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "integer_overflow")
  assert_eq(parse("a=0xFFFFFFFFL").lookup("a").as_int64(), 4294967295L)
}

///|
test "target mode matches historical string comment and overflow read behavior" {
  assert_eq(parse_target(b"a=1 /*").get_int("a"), 1)
  assert_eq(parse_target(b"a=\"\\u1234\"").get_bytes("a"), b"\\u1234")
  assert_eq(parse_target(b"a=\"\\xG0\"").get_bytes("a"), b"\\xG0")
  assert_eq(parse_target(b"a=\"\\x0\"").get_bytes("a"), b"\\x0")
  assert_eq(parse_target(b"a=\"\\x00tail\"").get_bytes("a"), b"")
  let tree = parse_target(b"a=1e999 b=1").root()
  assert_true(tree.lookup("a").as_double().is_inf())
  let code = try {
    ignore(stringify(tree))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "non_finite_float")
  let edited = replace_source_value(b"a=1e999 b=1", "b", Integer(2))
  assert_true(parse_target(edited).get_double("a").is_inf())
}

///|
test "include resolver identity and literal syntax are enforced" {
  let root : IncludeFile = {
    id: "r",
    content: b"@include \"one\"\n@include \"two\"\n",
  }
  let code = try {
    ignore(
      parse_with_includes(root, (_, name) => {
        id: "same",
        content: if name == "one" {
          b"a=1"
        } else {
          b"b=2"
        },
      }),
    )
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "include_identity")
  for
    content in [
      b"a=1 @include \"c\"", b"@include \"c\";", b"@include \"a\"\n\"b\"",
    ] {
    let code = try {
      ignore(
        parse_with_includes({ id: "r", content, }, (_, _) => {
          id: "c",
          content: b"x=1",
        }),
      )
      "accepted"
    } catch {
      ConfigError(d) => d.code
    }
    assert_eq(code, "include_syntax")
  }
}

///|
test "included duplicate settings and resolver failures remain visible" {
  let code = try {
    ignore(
      parse_with_includes({ id: "r", content: b"a=1\n@include \"c\"\n", }, (
        _,
        _,
      ) => { id: "c", content: b"a=2", }),
    )
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(code, "duplicate_name")
  let issue = try {
    ignore(
      parse_with_includes({ id: "r", content: b"@include \"missing\"\n", }, (
        _,
        _,
      ) => raise failure("missing_source", "not found")),
    )
    None
  } catch {
    ConfigError(d) => Some(d)
  }
  guard issue is Some(d) else { fail("expected missing source") }
  assert_eq(d.code, "missing_source")
  assert_true(d.message.contains("r:") && d.message.contains("missing"))
}

///|
test "target normalized writer and edited numeric fields preserve requested type" {
  let root = parse_target(b"a=0xFFFFFFFFL b=0x100000000L").root()
  assert_eq(parse_target(@utf8.encode(stringify(root))).root(), root)
  let output = replace_source_value(
    b"mask=0xFFFFFFFFL; port=9000",
    "mask",
    Integer64(4294967295L),
  )
  assert_eq(parse_target(output).get_int64("mask"), 4294967295L)
  assert_true(@utf8.decode(output).contains("4294967295L"))
}

///|
test "include resolver expands at textual positions and tracks nested file origin" {
  let doc = parse_with_includes(
    { id: "root", content: b"svc={\n@include \"child\"\n}\n", },
    (parent, name) => {
      if parent == "root" && name == "child" {
        { id: "child.cfg", content: b"port=9000\n@include \"more\"\n", }
      } else if parent == "child.cfg" && name == "more" {
        { id: "more.cfg", content: b"enabled=true", }
      } else {
        raise failure("unexpected_resolver_request", parent + ":" + name)
      }
    },
  )
  assert_eq(doc.root().lookup("svc.port"), Integer(9000))
  assert_true(doc.root().lookup("svc.enabled").as_bool())
  guard doc.origin("svc.port") is Some(origin) else { fail("missing origin") }
  assert_eq(origin.source, "child.cfg")
  assert_eq((origin.position.line, origin.position.column), (1, 6))
  guard doc.origin("svc.enabled") is Some(origin) else {
    fail("missing nested origin")
  }
  assert_eq(origin.source, "more.cfg")
}

///|
test "textual include works inside list and ignores directives inside comments and strings" {
  let doc = parse_with_includes(
    {
      id: "r",
      content: b"# @include \"no\"\ns=\"@include\"; items=(\n@include \"values\"\n)",
    },
    (_, _) => { id: "values", content: b"1,2L,true", },
  )
  assert_eq(
    doc.root().lookup("items"),
    List([Integer(1), Integer64(2L), Boolean(true)]),
  )
}

///|
test "include cycles depth and cumulative input budgets are errors" {
  let root : IncludeFile = { id: "r", content: b"@include \"c\"\n", }
  let cycle = try {
    ignore(parse_with_includes(root, (_, _) => root))
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(cycle, "include_cycle")
  let depth = try {
    ignore(
      parse_with_includes(
        root,
        (_, _) => { id: "c", content: b"a=1", },
        max_include_depth=0,
      ),
    )
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(depth, "include_depth")
  let budget = try {
    ignore(
      parse_with_includes(root, (_, _) => { id: "c", content: b"a=1", }, limits={
        ..Limits::default(),
        max_input: 14,
      }),
    )
    "accepted"
  } catch {
    ConfigError(d) => d.code
  }
  assert_eq(budget, "input_limit")
}

///|
test "included parse and lookup errors map back to original file" {
  let root : IncludeFile = { id: "r", content: b"@include \"c\"\n", }
  let diagnostic = try {
    ignore(
      parse_with_includes(root, (_, _) => { id: "c", content: b"a=1\nb=\n", }),
    )
    None
  } catch {
    ConfigError(d) => Some(d)
  }
  guard diagnostic is Some(d) else { fail("expected child parse error") }
  assert_true(d.message.contains("c:"))
  assert_eq(d.line, 2)
  let doc = parse_with_includes(root, (_, _) => { id: "c", content: b"a=1", })
  let diagnostic = try {
    ignore(doc.lookup("a.child"))
    None
  } catch {
    ConfigError(d) => Some(d)
  }
  guard diagnostic is Some(d) else { fail("expected child lookup error") }
  assert_eq((d.line, d.column), (1, 3))
  assert_true(d.message.contains("c:"))
}
