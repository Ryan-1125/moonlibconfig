param([string]$SdkPath = "$PSScriptRoot\..\.local\toolchains\20261119")
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot\..").Path
$sdk=(Resolve-Path $SdkPath).Path
if(!(Test-Path -LiteralPath "$sdk\bin\moon.exe")){throw 'Matching MoonBit SDK required'}
$report=[ordered]@{module='Ryan-1125/moonlibconfig';version=[regex]::Match([IO.File]::ReadAllText("$root\moon.mod"),'version\s*=\s*"([^"]+)"').Groups[1].Value;commit=(& git -C $root rev-parse HEAD);steps=@();result='running'}
$oldHome=$env:MOON_HOME;$oldPath=$env:PATH
function Invoke-Check([string]$Name,[scriptblock]$Action){
  $watch=[Diagnostics.Stopwatch]::StartNew()
  try {
    & $Action
    if($LASTEXITCODE -ne 0){throw "Exit code $LASTEXITCODE"}
    $report.steps += [ordered]@{name=$Name;result='passed';seconds=$watch.Elapsed.TotalSeconds}
  } catch {
    $report.steps += [ordered]@{name=$Name;result='failed';message=$_.Exception.Message}
    throw
  }
}
try {
  $env:MOON_HOME=$sdk;$env:PATH="$sdk\bin;$oldPath"
  Invoke-Check 'toolchain' { moon version --all }
  Invoke-Check 'format' { moon -C $root fmt --check }
  Invoke-Check 'strict check' { moon -C $root check --deny-warn }
  foreach($target in @('wasm-gc','js','native')){
    Invoke-Check "build $target" { moon -C $root build --target $target --deny-warn }
    Invoke-Check "test $target" { moon -C $root test --target $target --deny-warn }
  }
  Invoke-Check 'public API' { moon -C $root info }
  Invoke-Check 'API snapshot' { git -C $root diff --exit-code -- pkg.generated.mbti }
  Invoke-Check 'ZIP independent consumer' { & "$PSScriptRoot\Test-Consumer.ps1" }
  if(!(Test-Path -LiteralPath "$root\.local\upstream\libconfig-a42cb47c1526a4f2ed025fcbb2289863375bc898\lib\libconfig.h")){
    Invoke-Check 'fixed upstream download' { & "$PSScriptRoot\Get-Upstream.ps1" }
  }
  Invoke-Check 'real upstream build' { & "$PSScriptRoot\Build-Oracle.ps1" }
  Push-Location $root
  try {
    Invoke-Check 'portable differential' { node tools/differential.mjs }
    Invoke-Check 'target differential' { node tools/differential.mjs --target-profile }
    Invoke-Check 'original application readback' { node tools/semantic-edit.mjs }
    Invoke-Check 'registry independent consumer' { & "$PSScriptRoot\Test-RegistryConsumer.ps1" }
  } finally { Pop-Location }
  $report.result='passed'
} catch {
  $report.result='failed'
  throw
} finally {
  $env:MOON_HOME=$oldHome;$env:PATH=$oldPath
  New-Item -ItemType Directory -Force "$root\.local\acceptance" | Out-Null
  $report | ConvertTo-Json -Depth 8 | Set-Content "$root\.local\acceptance\report.json" -Encoding utf8
}
Write-Output "Acceptance passed: $root\.local\acceptance\report.json"
