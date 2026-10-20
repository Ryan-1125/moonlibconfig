///|
test "fixed scalar vectors preserve width and base bit patterns" {
  let cases : Array[(Bytes, Value)] = [
    (b"-2147483648", Integer(-2147483648)),
    (b"2147483648", Integer64(2147483648L)),
    (b"9223372036854775807L", Integer64(9223372036854775807L)),
    (b"-9223372036854775808L", Integer64(-9223372036854775808L)),
    (b"0xffffffff", Integer(-1)),
    (b"0xffffffffL", Integer64(4294967295L)),
    (b"0xffffffffffffffff", Integer64(-1L)),
    (b"0b1011", Integer(11)),
    (b"0q755", Integer(493)),
    (b"1.25e+2", Float(125.0)),
    (b"TrUe", Boolean(true)),
  ]
  for (input, expected) in cases {
    assert_eq(Reader::new(input, Limits::default()).atom(), expected)
  }
}

///|
test "numeric overflows and malformed literals" {
  for
    input in [
      b"9223372036854775808", b"-9223372036854775809", b"0x", b"0b2", b"1e", b"1.0L",
      b"NaN", b"1e999", b"0xfffffffffffffffff", b"+",
    ] {
    let rejected = try {
      ignore(Reader::new(input, Limits::default()).atom())
      false
    } catch {
      ConfigError(_) => true
    }
    assert_true(rejected)
  }
}
