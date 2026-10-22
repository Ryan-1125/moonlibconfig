///|
/// A semantic/resource issue in a caller-constructed configuration. Empty path is root.
pub(all) struct ValidationIssue {
  path : String
  code : String
  message : String
} derive(Debug, Eq)

///|
priv struct Validator {
  limits : Limits
  issues : Array[ValidationIssue]
  mut nodes : Int32
  mut stopped : Bool
}

///| Check structure and limits without serialization. max_input is not an output budget here.

///|
/// Returns independent issues; traversal stops on the global node budget.
pub fn validate(
  root : Value,
  limits~ : Limits = Limits::default(),
) -> Array[ValidationIssue] raise ConfigError {
  ignore(Reader::new(b"", limits))
  let v : Validator = { limits, issues: [], nodes: 0, stopped: false, }
  match root {
    Group(items) => v.group(items, "", 0)
    _ =>
      v.issue("", "type_mismatch", "expected root group; actual " + root.kind())
  }
  v.issues
}

///|
fn member_path(parent : String, name : String) -> String {
  if parent == "" {
    name
  } else {
    parent + "." + name
  }
}

///|
fn Validator::issue(
  self : Validator,
  path : String,
  code : String,
  message : String,
) -> Unit {
  self.issues.push({ path, code, message, })
}

///|
fn Validator::group(
  self : Validator,
  items : Array[(String, Value)],
  path : String,
  depth : Int32,
) -> Unit {
  let names : Map[String, Bool] = Map([])
  for (name, value) in items {
    if self.stopped {
      break
    }
    let child = member_path(path, name)
    check_name(name) catch {
      ConfigError(d) => self.issue(child, d.code, d.message)
    }
    if names.contains(name) {
      self.issue(child, "duplicate_name", "duplicate setting: " + name)
    }
    names[name] = true
    self.visit(value, child, depth)
  }
}

///|
fn Validator::visit(
  self : Validator,
  value : Value,
  path : String,
  depth : Int32,
) -> Unit {
  if self.nodes >= self.limits.max_nodes {
    self.issue(path, "node_limit", "value count exceeds limit")
    self.stopped = true
    return
  }
  self.nodes += 1
  match value {
    Float(v) =>
      if v.is_inf() || v.is_nan() {
        self.issue(path, "non_finite_float", "expected finite float")
      }
    Text(bytes) =>
      if bytes.length() > self.limits.max_string {
        self.issue(path, "string_limit", "decoded string exceeds byte limit")
      } else {
        for b in bytes {
          if b == b'\x00' {
            self.issue(
              path, "unsupported_nul", "NUL is not representable by libconfig string APIs",
            )
            break
          }
        }
      }
    Group(items) =>
      if depth >= self.limits.max_depth {
        self.issue(path, "depth_limit", "container nesting exceeds limit")
      } else {
        self.group(items, path, depth + 1)
      }
    ScalarArray(items) | List(items) => {
      if depth >= self.limits.max_depth {
        self.issue(path, "depth_limit", "container nesting exceeds limit")
        return
      }
      for i = 0; i < items.length(); i = i + 1 {
        if self.stopped {
          break
        }
        let child = path + "[" + i.to_string() + "]"
        if value is ScalarArray(_) {
          match items[i] {
            Group(_) | ScalarArray(_) | List(_) =>
              self.issue(
                child,
                "array_type",
                "array element must be scalar; actual " + items[i].kind(),
              )
            _ => ()
          }
          if i > 0 && items[0].kind() != items[i].kind() {
            self.issue(
              child,
              "array_type",
              "expected " + items[0].kind() + "; actual " + items[i].kind(),
            )
          }
        }
        self.visit(items[i], child, depth + 1)
      }
    }
    _ => ()
  }
}
