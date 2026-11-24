///| Replace one existing value in the original bytes, preserving all other bytes.

///| This is the preferred route when returning existing configuration to its original application.

///|
/// The source must satisfy the current parser's syntax contract; include expansion belongs to the caller.
pub fn replace_source_value(
  input : Bytes,
  path : String,
  replacement : Value,
  limits~ : Limits = Limits::default(),
) -> Bytes raise ConfigError {
  let document = parse_target(input, limits~)
  ignore(document.lookup(path))
  if path == "" {
    raise failure(
      "invalid_path", "source editing requires an existing setting or element",
    )
  }
  guard document.location(path) is Some(location) else {
    raise failure("missing_member", "source location missing")
  }
  let reader = Reader::new(input, limits)
  reader.policy = Libconfig182
  reader.pos = location.value.offset
  reader.line = location.value.line
  reader.column = location.value.column
  let original = reader.value(0)
  let end = if original is Text(_) { reader.last_text_end } else { reader.pos }
  let encoded = @utf8.encode(stringify(Group([("v", replacement)]), limits~))
  let literal = encoded[4:encoded.length() - 2]
  let output = input[0:location.value.offset].to_owned() +
    literal.to_owned() +
    input[end:input.length()].to_owned()
  if output.length() > limits.max_input {
    raise failure("output_limit", "edited source exceeds byte limit")
  }
  let rewritten = parse_target(output, limits~)
  if rewritten.lookup(path) != replacement {
    raise failure(
      "target_value_mismatch", "target application would interpret replacement differently",
    )
  }
  return output
}
