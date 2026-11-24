param(
  [Parameter(Position=0)][string]$Command='check',
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$MoonArgs
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot\..").Path
$sdk=Join-Path $root '.local\toolchains\20261119'
if(!(Test-Path -LiteralPath "$sdk\bin\moon.exe")) { throw 'Isolated SDK missing. Use moonc 0.10.22 with its matching core, or install official binaries into .local/toolchains/20261119.' }
$oldHome=$env:MOON_HOME
$oldPath=$env:PATH
try {
  $env:MOON_HOME=$sdk
  $env:PATH="$sdk\bin;$oldPath"
  & "$sdk\bin\moon.exe" -C $root $Command @MoonArgs
  if($LASTEXITCODE -ne 0){throw "moon $Command failed: $LASTEXITCODE"}
} finally {
  $env:MOON_HOME=$oldHome
  $env:PATH=$oldPath
}
