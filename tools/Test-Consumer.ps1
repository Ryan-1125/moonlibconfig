$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..").Path
& moon -C $root package --list
if ($LASTEXITCODE -ne 0) { throw 'Packaging failed' }
$archive = Join-Path $root '_build\publish\Ryan-1125-moonlibconfig-0.1.0.zip'
$work = Join-Path ([IO.Path]::GetTempPath()) ('moonlibconfig-consumer-' + [guid]::NewGuid().ToString('N'))
$library = Join-Path $work 'library'
$app = Join-Path $work 'app'
New-Item -ItemType Directory -Path $app -Force | Out-Null
Expand-Archive -LiteralPath $archive -DestinationPath $library
@'
members = ["library", "app"]
'@ | Set-Content -LiteralPath "$work\moon.work" -Encoding utf8
@'
name = "local/libconfig-consumer"
import { "Ryan-1125/moonlibconfig@0.1.0" }
'@ | Set-Content -LiteralPath "$app\moon.mod" -Encoding utf8
@'
import { "Ryan-1125/moonlibconfig" @config } for "test"
'@ | Set-Content -LiteralPath "$app\moon.pkg" -Encoding utf8
@'
///|
test "packaged public API consumer" {
  let source = @config.parse("server={port=9000} peers=({host=\"moon\"})")
  assert_eq(source.lookup("peers[0].host").as_string(), "moon")
  let changed = source.replaced(@config.parse_path("server.port"), @config.Integer(8080))
  let server = changed.lookup("server").with_member("workers", @config.Integer(4))
  let edited = changed.replaced(@config.parse_path("server"), server)
  assert_eq(edited.lookup("server.workers").as_int(), 4)
  let removed = server.without_member("workers")
  assert_eq(removed, changed.lookup("server"))
  let text = @config.stringify(edited)
  assert_eq(@config.parse(text).lookup("server.port").as_int(), 8080)
  assert_eq(source.lookup("server.port").as_int(), 9000)
}
'@ | Set-Content -LiteralPath "$app\consumer_test.mbt" -Encoding utf8
foreach ($target in @('wasm-gc','js','native')) {
  & moon -C $app test --target $target --deny-warn
  if ($LASTEXITCODE -ne 0) { throw "Packaged consumer failed on $target" }
}
Write-Output "Independent ZIP consumer passed on wasm-gc/js/native: $work"
