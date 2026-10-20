param(
  [string]$SourceDir = "$PSScriptRoot\..\.local\upstream\libconfig-a42cb47c1526a4f2ed025fcbb2289863375bc898",
  [string]$Compiler = '',
  [string]$MsvcRoot = '',
  [string]$WindowsSdk = 'C:\Program Files (x86)\Windows Kits\10',
  [string]$SdkVersion = ''
)
$ErrorActionPreference = 'Stop'
if (!$MsvcRoot) {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if (!$installation) { throw 'MSVC x64 tools not found; pass -MsvcRoot and -Compiler' }
  $MsvcRoot = (Get-ChildItem -LiteralPath "$installation\VC\Tools\MSVC" -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName
}
if (!$Compiler) { $Compiler = Join-Path $MsvcRoot 'bin\HostX64\x64\cl.exe' }
if (!$SdkVersion) {
  $SdkVersion = (Get-ChildItem -LiteralPath "$WindowsSdk\Include" -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name
}
$root = (Resolve-Path "$PSScriptRoot\..").Path
$lib = (Resolve-Path "$SourceDir\lib").Path
$out = Join-Path $root '.local\upstream'
New-Item -ItemType Directory -Force "$out\obj" | Out-Null
$includes = @("$MsvcRoot\include", "$WindowsSdk\Include\$SdkVersion\ucrt", "$WindowsSdk\Include\$SdkVersion\um", "$WindowsSdk\Include\$SdkVersion\shared", $lib)
$libs = @("$MsvcRoot\lib\x64", "$WindowsSdk\Lib\$SdkVersion\ucrt\x64", "$WindowsSdk\Lib\$SdkVersion\um\x64")
$sources = @('grammar.c','libconfig.c','scanctx.c','scanner.c','strbuf.c','strvec.c','util.c','wincompat.c') | ForEach-Object { Join-Path $lib $_ }
$arguments = @('/nologo','/std:c11','/O2','/MT','/DLIBCONFIG_STATIC','/DYY_NO_UNISTD_H','/D_CRT_SECURE_NO_WARNINGS',"/Fo$out\obj\", "/Fe$out\oracle.exe")
$arguments += $includes | ForEach-Object { "/I$_" }
$arguments += @("$PSScriptRoot\oracle.c") + $sources
$arguments += @('/link', 'shlwapi.lib') + @($libs | ForEach-Object { "/LIBPATH:$_" })
& $Compiler @arguments
if ($LASTEXITCODE -ne 0) { throw "Upstream oracle build failed: $LASTEXITCODE" }
Write-Output "Built external libconfig v1.8.2 oracle: $out\oracle.exe"
