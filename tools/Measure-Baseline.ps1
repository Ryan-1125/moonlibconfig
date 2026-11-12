param([ValidateSet('wasm-gc','js','native')][string]$Target='native', [int]$Runs=5)
$ErrorActionPreference='Stop'
if($Runs -lt 3 -or $Runs -gt 30){throw 'Runs must be between 3 and 30'}
$root=(Resolve-Path "$PSScriptRoot\..").Path
# Warm compile/cache first. Measurements include process startup and test harness overhead.
& moon -C $root test --target $Target --filter '*corpus*' --deny-warn
if($LASTEXITCODE -ne 0){throw 'Warm-up failed'}
$samples=@()
for($i=0;$i -lt $Runs;$i++){
  $watch=[Diagnostics.Stopwatch]::StartNew()
  & moon -C $root test --target $Target --filter '*corpus*' --deny-warn
  $watch.Stop()
  if($LASTEXITCODE -ne 0){throw 'Measurement workload failed'}
  $samples += $watch.Elapsed.TotalMilliseconds
}
$ordered=@($samples | Sort-Object)
$report=[ordered]@{target=$Target;runs=$Runs;workload='1000 deterministic mutations, seed 1729';measurement='warm end-to-end moon test wall time, including startup; not parser throughput';median_ms=$ordered[[int][Math]::Floor($Runs/2)];samples_ms=$samples}
New-Item -ItemType Directory -Force "$root/.local/benchmarks" | Out-Null
$report | ConvertTo-Json | Set-Content "$root/.local/benchmarks/$Target.json" -Encoding utf8
$report | ConvertTo-Json
