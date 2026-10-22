///| Return a list/array with a new element inserted before index (length appends).

///|
/// Containers are copied; unchanged elements are shared.
pub fn Value::inserted(
  self : Value,
  index : Int32,
  value : Value,
) -> Value raise ConfigError {
  let items = match self {
    ScalarArray(v) | List(v) => v
    _ =>
      raise failure(
        "type_mismatch",
        "expected array or list; actual " + self.kind(),
      )
  }
  if index < 0 || index > items.length() {
    raise failure(
      "index_out_of_bounds", "insertion index must be between zero and length",
    )
  }
  if self is ScalarArray(_) {
    match value {
      Group(_) | ScalarArray(_) | List(_) =>
        raise failure("array_type", "array elements must be scalars")
      _ => ()
    }
    if items.length() > 0 && items[0].kind() != value.kind() {
      raise failure(
        "array_type",
        "expected " + items[0].kind() + "; actual " + value.kind(),
      )
    }
  }
  let output : Array[Value] = []
  for i = 0; i < items.length(); i = i + 1 {
    if i == index {
      output.push(value)
    }
    output.push(items[i])
  }
  if index == items.length() {
    output.push(value)
  }
  match self {
    ScalarArray(_) => ScalarArray(output)
    _ => List(output)
  }
}

///|
/// Append a scalar to an array or any value to a list.
pub fn Value::appended(self : Value, value : Value) -> Value raise ConfigError {
  let size = match self {
    ScalarArray(v) | List(v) => v.length()
    _ =>
      raise failure(
        "type_mismatch",
        "expected array or list; actual " + self.kind(),
      )
  }
  self.inserted(size, value)
}

///|
/// Remove an existing list/array element; remaining elements retain order.
pub fn Value::removed_at(
  self : Value,
  index : Int32,
) -> Value raise ConfigError {
  ignore(self.at(index))
  let items = match self {
    ScalarArray(v) | List(v) => v
    _ => raise failure("type_mismatch", "expected array or list")
  }
  let output : Array[Value] = []
  for i = 0; i < items.length(); i = i + 1 {
    if i != index {
      output.push(items[i])
    }
  }
  match self {
    ScalarArray(_) => ScalarArray(output)
    _ => List(output)
  }
}
