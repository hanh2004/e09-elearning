param(
  [ValidateSet('admin', 'user')][string]$Portal = 'admin',
  [string]$Node = 'node'
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
  # A fresh output avoids reusing incomplete asset copies from the other portal.
  $staging = Join-Path $PSScriptRoot ('build\web-verified-' + [guid]::NewGuid().ToString('N'))
  & flutter build web --release --target "lib/main_$Portal.dart" --no-pub --no-web-resources-cdn -o $staging
  if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed. Current published bundle was kept.' }
  & $Node functions/scripts/verify-web-build.mjs $staging
  if ($LASTEXITCODE -ne 0) { throw 'Asset verification failed. Do not deploy this build.' }
  $output = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "build\${Portal}_web"))
  $buildRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'build')) + [IO.Path]::DirectorySeparatorChar
  if (-not $output.StartsWith($buildRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Output must stay inside build.' }
  if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
  Move-Item -LiteralPath $staging -Destination $output
  Write-Output "Ready: $output"
} finally { Pop-Location }
