///|
fn main {
  try {
    let input = b"mask=0xFFFFFFFFL; bits=0x100000000L; port=9000; ratio=-0.0; text=\"\\xFF\"; title=\"moon\"; numbers=[1,2]; nested={ok=true;};"
    let edits : Array[(String, @config.Value)] = [
      ("port", @config.Integer(8080)),
      ("mask", @config.Integer64(4294967295L)),
      ("title", @config.Text(b"new")),
      ("numbers", @config.ScalarArray([@config.Integer(1), @config.Integer(3)])),
      ("nested.ok", @config.Boolean(false)),
      ("ratio", @config.Float(0.125)),
      ("text", @config.Text(b"\x80")),
    ]
    for (path, value) in edits {
      let output = @config.replace_source_value(input, path, value)
      println(@json.to_json([path, @utf8.decode(output)]).stringify())
    }
    let root : @config.IncludeFile = {
      id: "root.cfg",
      content: b"service={\n@include \"child.cfg\"\n}\nport=9000;",
    }
    let child = b"mask=0xFFFFFFFFL; bits=0x100000000L;"
    let doc = @config.parse_with_includes(root, (_, _) => {
      id: "child.cfg",
      content: child,
    })
    if doc.root().lookup("service.mask").as_int64() != -1L {
      panic()
    }
    let output = @config.replace_source_value(
      child,
      "bits",
      @config.Integer64(5L),
    )
    println(@json.to_json(["include-child", @utf8.decode(output)]).stringify())
  } catch {
    _ => panic()
  }
}
