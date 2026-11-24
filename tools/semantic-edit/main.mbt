///|
fn main {
  try {
    let input = b"mask=0xFFFFFFFFL; bits=0x100000000L; port=9000; text=\"\\xFF\"; nested={ok=true;};"
    let output = @config.replace_source_value(
      input,
      "port",
      @config.Integer(8080),
    )
    println(@config.parse_bytes(output).lookup("port").as_int())
    println(@utf8.decode(output))
  } catch {
    _ => panic()
  }
}
