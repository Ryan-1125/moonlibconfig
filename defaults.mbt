///| Return None only for a missing member or out-of-bounds index.

///|
/// Malformed paths and type errors remain errors.
pub fn Value::lookup_optional(
  self : Value,
  path : String,
) -> Value? raise ConfigError {
  Some(self.lookup(path)) catch {
    ConfigError(d) =>
      if d.code == "missing_member" || d.code == "index_out_of_bounds" {
        None
      } else {
        raise ConfigError(d)
      }
  }
}

///|
/// Use a default only for a missing value. Existing values must match its exact type.
pub fn Value::lookup_or(
  self : Value,
  path : String,
  default : Value,
) -> Value raise ConfigError {
  match self.lookup_optional(path) {
    None => default
    Some(value) => {
      if value.kind() != default.kind() {
        raise failure(
          "type_mismatch",
          "at " +
          path +
          ": expected " +
          default.kind() +
          "; actual " +
          value.kind(),
        )
      }
      value
    }
  }
}
