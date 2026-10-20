///|
fn hex(bytes : Bytes) -> String {
  let out = StringBuilder()
  let digits = "0123456789abcdef"
  for b in bytes {
    let n = b.to_int()
    out.write_stringview(digits[n / 16:n / 16 + 1])
    out.write_stringview(digits[n % 16:n % 16 + 1])
  }
  out.to_string()
}

///|
fn snapshot(v : @config.Value) -> Json {
  let data = match v {
    Integer(n) => Json::string(n.to_string())
    Integer64(n) => Json::string(n.to_string())
    Float(n) =>
      Json::string(
        if n == 0.0 && n.reinterpret_as_int64() < 0L {
          "-0"
        } else {
          n.to_string()
        },
      )
    Boolean(b) => Json::boolean(b)
    Text(b) => Json::string(hex(b))
    Group(items) =>
      Json::array(
        items.map(pair => {
          Json::array([
            Json::string(hex(@utf8.encode(pair.0))),
            snapshot(pair.1),
          ])
        }),
      )
    ScalarArray(items) | List(items) => Json::array(items.map(snapshot))
  }
  Json::array([Json::string(v.kind()), data])
}

///|
fn main {
  for bytes in cases() {
    let result = try {
      let root = @config.parse_bytes(bytes)
      Json::array([
        Json::boolean(true),
        snapshot(root),
        Json::string(@config.stringify(root)),
      ])
    } catch {
      @config.ConfigError(d) =>
        Json::array([Json::boolean(false), Json::string(d.code)])
    }
    println(@json.to_json(result).stringify())
  }
}
