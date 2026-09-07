$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$localNode = Join-Path $projectDir '.tmp\node22\node.exe'
$nodePath = if (Test-Path -LiteralPath $localNode) { $localNode } else { (Get-Command node -ErrorAction Stop).Source }
$nodeMajor = [int]((& $nodePath --version).TrimStart('v').Split('.')[0])
if ($nodeMajor -lt 22) { throw 'Install Node 22 or newer before running the local backend.' }
$firebaseCli = Join-Path $projectDir 'functions\node_modules\firebase-tools\lib\bin\firebase.js'
if (!(Test-Path -LiteralPath $firebaseCli)) { throw 'Run npm ci inside functions first.' }
$previousPath = $env:PATH
try {
  # Use the real Java executable, not Oracle's Windows javapath launcher,
  # so stopping the emulator also stops its JVM instead of leaving port 8080 busy.
  $javaSettings = & java -XshowSettings:properties -version 2>&1
  $javaHomeLine = $javaSettings | ForEach-Object { $_.ToString() } | Where-Object { $_ -match '^\s*java.home\s*=' } | Select-Object -First 1
  if (!$javaHomeLine) { throw 'Cannot locate the Java runtime. Install Java 17 or newer.' }
  $javaBin = Join-Path (($javaHomeLine -replace '^\s*java.home\s*=\s*', '').Trim()) 'bin'
  if (!(Test-Path -LiteralPath (Join-Path $javaBin 'java.exe'))) { throw 'Java executable not found.' }
  $env:PATH = (Split-Path -Parent $nodePath) + ';' + $javaBin + ';' + $env:PATH
  Push-Location $projectDir
  try {
    & $nodePath $firebaseCli emulators:exec --config firebase.secure.json --project demo-e09 --only auth,firestore,functions --import .tmp/firebase-local --export-on-exit .tmp/firebase-local 'node functions/scripts/local-session.js'
    if ($LASTEXITCODE -ne 0) { throw 'Local backend stopped with an error. Check the output above.' }
  } finally { Pop-Location }
} finally { $env:PATH = $previousPath }
