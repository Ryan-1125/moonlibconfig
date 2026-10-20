$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot\..").Path
$work = Join-Path $root '.local\upstream'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$archive = Join-Path $work 'libconfig.tar.gz'
$commit = 'a42cb47c1526a4f2ed025fcbb2289863375bc898'
Invoke-WebRequest -Uri "https://codeload.github.com/hyperrealm/libconfig/tar.gz/$commit" -OutFile $archive
$expected = '85298E5676BFE9EB0E5DAB833B79E5963F903D20A44D1BC76D968AEE909A261B'
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expected) {
  throw 'Upstream archive checksum differs; inspect before changing expected hash'
}
& tar -xzf $archive -C $work
if ($LASTEXITCODE -ne 0) { throw 'Extraction failed' }
Write-Output "Verified external upstream archive at commit $commit"
