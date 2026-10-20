///|
fn hex_digit(c : Int32) -> Int32 {
  if c >= 48 && c <= 57 {
    c - 48
  } else if c >= 65 && c <= 70 {
    c - 55
  } else if c >= 97 && c <= 102 {
    c - 87
  } else {
    -1
  }
}

///|
fn Reader::text(self : Reader) -> Bytes raise ConfigError {
  let output : Array[Byte] = []
  while self.peek() == 34 {
    self.advance()
    while self.peek() != 34 {
      if self.peek() == -1 {
        raise self.error("unterminated_string", "expected closing quote")
      }
      let mut c = self.peek()
      self.advance()
      if c == 92 {
        c = match self.peek() {
          34 => 34
          92 => 92
          97 => 7
          98 => 8
          102 => 12
          110 => 10
          114 => 13
          116 => 9
          118 => 11
          120 => {
            self.advance()
            let hi = hex_digit(self.peek())
            if hi < 0 {
              raise self.error(
                "invalid_escape", "expected two hexadecimal digits",
              )
            }
            self.advance()
            let lo = hex_digit(self.peek())
            if lo < 0 {
              raise self.error(
                "invalid_escape", "expected two hexadecimal digits",
              )
            }
            hi * 16 + lo
          }
          _ => raise self.error("invalid_escape", "unknown string escape")
        }
        self.advance()
      }
      if c == 0 {
        raise self.error(
          "unsupported_nul", "NUL bytes are not representable by libconfig string APIs",
        )
      }
      if output.length() >= self.limits.max_string {
        raise self.error("string_limit", "decoded string exceeds byte limit")
      }
      output.push(c.to_byte())
    }
    self.advance()
    self.skip()
  }
  Bytes::from_array(output)
}
