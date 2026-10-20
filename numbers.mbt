///|
fn digit(c : Int32) -> Bool {
  c >= 48 && c <= 57
}

///|
fn decimal_syntax(data : BytesView) -> Bool {
  let mut i = 0
  if data.length() > 0 && (data[0] == b'+' || data[0] == b'-') {
    i += 1
  }
  let start = i
  while i < data.length() && digit(data[i].to_int()) {
    i += 1
  }
  let mut digits = i - start
  if i < data.length() && data[i] == b'.' {
    i += 1
    let fraction = i
    while i < data.length() && digit(data[i].to_int()) {
      i += 1
    }
    digits += i - fraction
  }
  if digits == 0 {
    return false
  }
  if i < data.length() && (data[i] == b'e' || data[i] == b'E') {
    i += 1
    if i < data.length() && (data[i] == b'+' || data[i] == b'-') {
      i += 1
    }
    let exponent = i
    while i < data.length() && digit(data[i].to_int()) {
      i += 1
    }
    if exponent == i {
      return false
    }
  }
  i == data.length()
}

///|
fn Reader::atom(self : Reader) -> Value raise ConfigError {
  let start = self.pos
  while ({
          let c = self.peek()
          (c >= 65 && c <= 90) ||
          (c >= 97 && c <= 122) ||
          digit(c) ||
          c == 43 ||
          c == 45 ||
          c == 46
        }) {
    self.advance()
  }
  let raw = @utf8.decode_lossy(self.data[start:self.pos])
  let lower = raw.to_lower()
  if lower == "true" {
    return Boolean(true)
  }
  if lower == "false" {
    return Boolean(false)
  }
  let long = raw.has_suffix("L") || raw.has_suffix("LL")
  let suffix = if raw.has_suffix("LL") { 2 } else if long { 1 } else { 0 }
  let end = self.pos - suffix
  if end <= start {
    raise self.error("invalid_number", "expected numeric value")
  }
  let number = @utf8.decode_lossy(self.data[start:end]).to_lower()
  let base = if number.has_prefix("0x") {
    16
  } else if number.has_prefix("0b") {
    2
  } else if number.has_prefix("0o") || number.has_prefix("0q") {
    8
  } else {
    10
  }
  if base != 10 {
    let n = end - start - 2
    let max32 = if base == 16 { 8 } else if base == 8 { 10 } else { 32 }
    let max64 = if base == 16 { 16 } else if base == 8 { 21 } else { 64 }
    if n < 1 || n > max64 {
      raise self.error("integer_overflow", "invalid base integer width")
    }
    for i = start + 2; i < end; i = i + 1 {
      let d = hex_digit(self.data[i].to_int())
      if d < 0 || d >= base {
        raise self.error("invalid_number", "invalid digit for base")
      }
    }
    let digits = @utf8.decode_lossy(self.data[start + 2:end])
    let bits = @string.parse_uint64(digits, base~) catch {
      _ => raise self.error("integer_overflow", "integer exceeds 64 bits")
    }
    if long || n > max32 {
      return Integer64(bits.reinterpret_as_int64())
    }
    return Integer(bits.to_int())
  }
  if !decimal_syntax(self.data[start:end]) {
    raise self.error("invalid_number", "invalid decimal or boolean")
  }
  if number.contains(".") || number.contains("e") || number.contains("E") {
    if long {
      raise self.error("invalid_number", "float cannot have integer suffix")
    }
    let v = @string.parse_double(number) catch {
      _ => raise self.error("invalid_number", "invalid floating point number")
    }
    if v.is_inf() || v.is_nan() {
      raise self.error("float_overflow", "non-finite float")
    }
    Float(v)
  } else {
    let v = @string.parse_int64(number) catch {
      _ =>
        raise self.error("integer_overflow", "integer exceeds signed 64 bits")
    }
    if long || v < -2147483648L || v > 2147483647L {
      Integer64(v)
    } else {
      Integer(v.to_int())
    }
  }
}
