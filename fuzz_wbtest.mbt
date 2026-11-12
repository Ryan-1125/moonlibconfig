///|
/// Deterministic bounded mutation corpus: seed 1729; each backend sees identical inputs.
test "seeded mutation corpus either rejects or roundtrips without loss" {
  let original = b"service={port=9000;tag=\"moon\";} peers=(1L,true,[1,2],{a=3})"
  let alphabet = b"{}[](),;:=\"\\01239Labct #\n\xff"
  let mut seed = 1729
  for i = 0; i < 1000; i = i + 1 {
    seed = (seed * 17 + 31) % 65521
    let bytes = original.to_array()
    bytes[seed % bytes.length()] = alphabet[seed / 7 % alphabet.length()]
    let result = Some(parse_bytes(Bytes::from_array(bytes))) catch {
      ConfigError(_) => None
    }
    if result is Some(root) {
      assert_eq(validate(root), [])
      assert_eq(parse(stringify(root)), root)
    }
  }
}

///|
test "generated trees preserve widths and container kinds" {
  for i = 0; i < 500; i = i + 1 {
    let root = Group([
      ("id", Integer(i)),
      ("wide", Integer64(i.to_int64())),
      ("values", ScalarArray([Integer(i), Integer(i + 1)])),
      ("mixed", List([Boolean(i % 2 == 0), Text(b"\xff\n"), Group([])])),
    ])
    assert_eq(parse(stringify(root)), root)
  }
}
