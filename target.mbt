///|
/// Explicit numeric interpretation. Existing APIs retain their original Portable behavior.
#derive(Debug, Eq)
pub(all) enum NumericPolicy {
  Portable
  Libconfig182
}

///|
/// Parse with libconfig 1.8.2 numeric interpretation, including signed conversion before L.
pub fn parse_target(
  input : Bytes,
  limits~ : Limits = Limits::default(),
) -> Document raise ConfigError {
  let reader = Reader::new(input, limits)
  reader.policy = Libconfig182
  reader.trace = true
  let origin = reader.position()
  reader.locations[""] = { setting: origin, value: origin, }
  let tree = Group(reader.settings(0, -1))
  { tree, locations: reader.locations, }
}

///|
/// UTF-8 text convenience entry for the libconfig 1.8.2 target policy.
pub fn parse_target_text(
  input : String,
  limits~ : Limits = Limits::default(),
) -> Document raise ConfigError {
  if input.length() > limits.max_input && limits.max_input >= 0 {
    raise failure("input_limit", "input exceeds byte limit")
  }
  parse_target(@utf8.encode(input), limits~)
}
