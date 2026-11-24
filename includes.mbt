///|
/// Resolver supplies stable canonical identity and bytes. The library performs no I/O.
pub(all) struct IncludeFile {
  id : String
  content : Bytes
} derive(Debug, Eq)

///|
/// Original file and byte coordinates, distinct from expanded coordinates.
pub(all) struct SourceOrigin {
  source : String
  position : SourcePosition
} derive(Debug, Eq)

///|
pub struct OriginChunk {
  first : Int32
  last : Int32
  source : String
  offset : Int32
}

///|
/// Construct a resolver failure without exposing the error representation.
pub fn resolver_error(message : String) -> ConfigError {
  failure("include_resolver", message)
}

///|
/// Retrieve retained original bytes by canonical identity for application-controlled saving.
pub fn IncludedDocument::source(self : IncludedDocument, id : String) -> Bytes? {
  self.sources.get(id)
}

///|
pub struct IncludedDocument {
  document : Document
  chunks : Array[OriginChunk]
  sources : Map[String, Bytes]
}

///|
priv struct Expansion {
  out : Array[Byte]
  chunks : Array[OriginChunk]
  sources : Map[String, Bytes]
  stack : Array[String]
  limits : Limits
  max_depth : Int32
  mut total : Int32
}

///| Resolve literal includes at their textual position, including inside groups/lists.

///|
/// Resolver owns path policy and canonical identity. max_include_depth is 0..32.
pub fn parse_with_includes(
  root : IncludeFile,
  resolve : (String, String) -> IncludeFile raise ConfigError,
  limits~ : Limits = Limits::default(),
  max_include_depth~ : Int32 = 10,
) -> IncludedDocument raise ConfigError {
  ignore(Reader::new(b"", limits))
  if max_include_depth < 0 || max_include_depth > 32 {
    raise failure("invalid_limits", "include depth must be 0..32")
  }
  let state : Expansion = {
    out: [],
    chunks: [],
    sources: Map([]),
    stack: [],
    limits,
    max_depth: max_include_depth,
    total: 0,
  }
  state.expand(root, resolve, 0)
  let document = parse_target(Bytes::from_array(state.out), limits~) catch {
    ConfigError(d) => {
      let mut anchor = d.offset
      if anchor >= state.out.length() {
        anchor = state.out.length() - 1
        while anchor > 0 &&
              (
                state.out[anchor] == b'\n' ||
                state.out[anchor] == b'\r' ||
                state.out[anchor] == b' ' ||
                state.out[anchor] == b'\t'
              ) {
          anchor -= 1
        }
      }
      let origin = find_origin(state.chunks, state.sources, anchor)
      raise ConfigError({
        ..d,
        message: origin.source + ": " + d.message,
        offset: origin.position.offset,
        line: origin.position.line,
        column: origin.position.column,
      })
    }
  }
  { document, chunks: state.chunks, sources: state.sources, }
}

///|
fn Expansion::copy(
  self : Expansion,
  file : IncludeFile,
  first : Int32,
  last : Int32,
) -> Unit raise ConfigError {
  if last - first > self.limits.max_input - self.out.length() {
    raise failure("input_limit", "expanded input exceeds limit")
  }
  let start = self.out.length()
  for i = first; i < last; i = i + 1 {
    self.out.push(file.content[i])
  }
  if last > first {
    self.chunks.push({
      first: start,
      last: self.out.length(),
      source: file.id,
      offset: first,
    })
  }
}

///|
fn Expansion::expand(
  self : Expansion,
  file : IncludeFile,
  resolve : (String, String) -> IncludeFile raise ConfigError,
  depth : Int32,
) -> Unit raise ConfigError {
  if depth > self.max_depth {
    raise failure("include_depth", "include depth exceeded at " + file.id)
  }
  for id in self.stack {
    if id == file.id {
      raise failure("include_cycle", "include cycle at " + file.id)
    }
  }
  if file.content.length() > self.limits.max_input - self.total {
    raise failure("input_limit", "total loaded include bytes exceed limit")
  }
  self.total += file.content.length()
  match self.sources.get(file.id) {
    Some(previous) =>
      if previous != file.content {
        raise failure(
          "include_identity",
          "resolver changed content for " + file.id,
        )
      }
    None => self.sources[file.id] = file.content
  }
  self.stack.push(file.id)
  let r = Reader::new(file.content, self.limits)
  r.policy = Libconfig182
  r.trace = true
  r.current_path = file.id
  let mut copied = 0
  while r.peek() != -1 {
    r.skip()
    if r.peek() == 34 {
      ignore(r.text())
      continue
    }
    if r.peek() != 64 {
      r.advance()
      continue
    }
    let start = r.pos
    let directive_line = r.line
    let mut line_start = start
    while line_start > 0 && file.content[line_start - 1] != b'\n' {
      line_start -= 1
    }
    for i = line_start; i < start; i = i + 1 {
      if file.content[i] != b' ' && file.content[i] != b'\t' {
        raise r.error(
          "include_syntax",
          "include must occupy its own line in " + file.id,
        )
      }
    }
    r.advance()
    if r.name() != "include" {
      raise r.error("include_syntax", "expected include in " + file.id)
    }
    while r.peek() == 32 || r.peek() == 9 {
      r.advance()
    }
    if r.peek() != 34 || r.line != directive_line {
      raise r.error("include_syntax", "expected quoted literal path")
    }
    let path = Value::Text(r.text()).as_string()
    let end = r.last_text_end
    for i = start; i < end; i = i + 1 {
      if file.content[i] == b'\n' || file.content[i] == b'\r' {
        raise r.error(
          "include_syntax", "include path must be a single quoted literal on one line",
        )
      }
    }
    let mut tail = end
    while tail < file.content.length() && file.content[tail] != b'\n' {
      if file.content[tail] != b' ' &&
        file.content[tail] != b'\t' &&
        file.content[tail] != b'\r' {
        raise r.error("include_syntax", "unexpected text after include")
      }
      tail += 1
    }
    self.copy(file, copied, start)
    let child = resolve(file.id, path) catch {
      ConfigError(d) =>
        raise ConfigError({
          ..d,
          message: file.id + ": " + path + ": " + d.message,
        })
    }
    self.expand(child, resolve, depth + 1)
    copied = end
    r.pos = end
    r.line = directive_line
    r.column = end - line_start + 1
  }
  self.copy(file, copied, file.content.length())
  ignore(self.stack.pop())
}

///|
fn find_origin(
  chunks : Array[OriginChunk],
  sources : Map[String, Bytes],
  offset : Int32,
) -> SourceOrigin {
  let mut selected : OriginChunk? = None
  for chunk in chunks {
    if offset >= chunk.first && offset < chunk.last {
      selected = Some(chunk)
      break
    }
    if offset == chunk.last {
      selected = Some(chunk)
    }
  }
  guard selected is Some(chunk) else {
    return { source: "<expanded>", position: { offset, line: 1, column: 1, }, }
  }
  let source_offset = chunk.offset + offset - chunk.first
  let bytes = sources[chunk.source]
  let mut line = 1
  let mut column = 1
  for i = 0; i < source_offset && i < bytes.length(); i = i + 1 {
    if bytes[i] == b'\n' {
      line += 1
      column = 1
    } else {
      column += 1
    }
  }
  { source: chunk.source, position: { offset: source_offset, line, column, }, }
}

///|
pub fn IncludedDocument::root(self : IncludedDocument) -> Value {
  self.document.root()
}

///|
pub fn IncludedDocument::origin(
  self : IncludedDocument,
  path : String,
) -> SourceOrigin? raise ConfigError {
  match self.document.location(path) {
    None => None
    Some(location) =>
      Some(find_origin(self.chunks, self.sources, location.value.offset))
  }
}

///|
/// Query errors use original file coordinates and include source identity in the message.
pub fn IncludedDocument::lookup(
  self : IncludedDocument,
  path : String,
) -> Value raise ConfigError {
  self.document.lookup(path) catch {
    ConfigError(d) => {
      let origin = find_origin(self.chunks, self.sources, d.offset)
      raise ConfigError({
        ..d,
        message: origin.source + ": " + d.message,
        offset: origin.position.offset,
        line: origin.position.line,
        column: origin.position.column,
      })
    }
  }
}
