///|
/// In-memory service configuration: parse, query, replace and serialize.
fn main {
  try {
    let config = @config.parse(
      "service={name=\"demo\";port=9000;enabled=true;} peers=({host=\"localhost\";weight=1L;})",
    )
    let name = config.lookup("service.name").as_string()
    let port = config.lookup("service.port").as_int()
    let host = config.lookup("peers[0].host").as_string()
    println("Service: \{name}, port: \{port}, first peer: \{host}")
    let updated = config.replaced(
      @config.parse_path("service.port"),
      @config.Integer(8080),
    )
    let output = @config.stringify(updated)
    let reloaded = @config.parse(output)
    println("Updated port: \{reloaded.lookup("service.port").as_int()}")
    println(output)
  } catch {
    @config.ConfigError(d) => println("\{d.code}: \{d.message}")
  }
}
