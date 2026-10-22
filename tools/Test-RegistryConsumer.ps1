param([string]$Version = '')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..").Path
if (!$Version) { $Version = [regex]::Match([IO.File]::ReadAllText("$root\moon.mod"), 'version\s*=\s*"([^"]+)"').Groups[1].Value }
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Expected a stable semantic version' }
$readme = [IO.File]::ReadAllText((Join-Path $root 'README.md'))
$blocks = [regex]::Matches($readme, '(?s)```moonbit\r?\n(.*?)```')
if ($blocks.Count -lt 1) { throw 'Expected runnable MoonBit README examples' }
$work = Join-Path ([IO.Path]::GetTempPath()) ('moonlibconfig-readme-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
@"
name = "local/libconfig-readme-check"
import { "Ryan-1125/moonlibconfig@$Version" }
"@ | Set-Content -LiteralPath "$work\moon.mod" -Encoding utf8
@'
import { "Ryan-1125/moonlibconfig" @config } for "test"
'@ | Set-Content -LiteralPath "$work\moon.pkg" -Encoding utf8
($blocks | ForEach-Object { $_.Groups[1].Value }) -join "`n" | Set-Content -LiteralPath "$work\readme_test.mbt" -Encoding utf8
$targets = @('wasm-gc', 'js', 'native')
foreach ($target in $targets) {
  & moon -C $work test --target $target --deny-warn
  if ($LASTEXITCODE -ne 0) { throw "Published README example failed: $target" }
}
$proof = [ordered]@{
  module = 'Ryan-1125/moonlibconfig'
  version = $Version
  dependency_source = 'Mooncakes registry; no workspace or local path override'
  examples_per_target = $blocks.Count
  targets = $targets
  result = 'passed'
}
$proof | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$work\verification.json" -Encoding utf8
Write-Output "Published README examples passed: $work"
