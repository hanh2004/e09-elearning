param(
  [string]$FlutterExe = 'D:\flutter\bin\flutter.bat',
  [string]$FirebaseProject = 'e09-elearning'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $projectRoot 'web\app-release.json'
$manifestExisted = Test-Path -LiteralPath $manifestPath
$manifestBackup = if ($manifestExisted) { [IO.File]::ReadAllBytes($manifestPath) }
$manifestChanged = $false
$completed = $false
$previousPath = $env:PATH
Push-Location $projectRoot

try {
  $node22Directory = Join-Path $projectRoot '.tmp\node22'
  if (Test-Path (Join-Path $node22Directory 'node.exe')) {
    $env:PATH = "$node22Directory;$env:PATH"
  }
  & node (Join-Path $projectRoot 'functions\scripts\kiem_tra_cau_hinh_firebase.mjs') $FirebaseProject
  if ($LASTEXITCODE -ne 0) { throw 'Cấu hình Firebase release chưa hợp lệ. Sửa cấu hình trước khi build.' }

  & $FlutterExe build apk --release --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'Không build được APK release.' }

  $metadataPath = Join-Path $projectRoot 'build\app\outputs\apk\release\output-metadata.json'
  if (-not (Test-Path -LiteralPath $metadataPath)) {
    throw 'Không tìm thấy thông tin phiên bản APK sau khi build.'
  }
  $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
  $apkInfo = $metadata.elements | Select-Object -First 1
  $release = [ordered]@{
    versionName = [string]$apkInfo.versionName
    buildNumber = [int]$apkInfo.versionCode
  }

  $publishUpdateNotice = $true
  if (Test-Path -LiteralPath $manifestPath) {
    $publishedRelease = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $publishedBuildNumber = [int]$publishedRelease.buildNumber
    if ($release.buildNumber -le $publishedBuildNumber) {
      throw 'Số sau dấu + phải lớn hơn số build đã phát hành để Android cho phép cập nhật.'
    }
    $publishedVersion = [version]::Parse([string]$publishedRelease.versionName)
    $releaseVersion = [version]::Parse($release.versionName)
    if ($releaseVersion -lt $publishedVersion) {
      throw 'Không thể phát hành phiên bản thấp hơn phiên bản đã công bố.'
    }
    $publishUpdateNotice = $releaseVersion -gt $publishedVersion
  }

  # Ghi build cục bộ cả khi cùng phiên bản để không phát hành lại cùng versionCode.
  $manifestJson = $release | ConvertTo-Json
  $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
  $manifestChanged = $true
  [System.IO.File]::WriteAllText($manifestPath, "$manifestJson`n", $utf8WithoutBom)

  if ($publishUpdateNotice) {
    & $FlutterExe build web --release --no-pub --target lib/diem_vao_quan_tri.dart --output build/admin_web
    if ($LASTEXITCODE -ne 0) { throw 'Không build được Admin web.' }
  }

  $apkSource = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
  $outputDirectory = Join-Path $projectRoot 'outputs\internal'
  New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
  $apkName = "e09-hoc-vien-$($release.versionName)-build$($release.buildNumber).apk"
  $apkDestination = Join-Path $outputDirectory $apkName
  Copy-Item -LiteralPath $apkSource -Destination $apkDestination -Force

  if ($publishUpdateNotice) {
    $firebaseCli = Join-Path $projectRoot 'functions\node_modules\.bin\firebase.cmd'
    if (-not (Test-Path -LiteralPath $firebaseCli)) {
      throw 'Thiếu Firebase CLI. Cài dependencies trong functions rồi chạy lại.'
    }
    & $firebaseCli deploy --only hosting --project $FirebaseProject
    if ($LASTEXITCODE -ne 0) { throw 'Không cập nhật được Admin Hosting và thông tin bản phát hành.' }
  }
  $completed = $true

  Write-Host "Đã phát hành $($release.versionName) (build $($release.buildNumber))."
  Write-Host "APK: $apkDestination"
  if ($publishUpdateNotice) {
    Write-Host 'Đã cập nhật app-release.json và phát hành thông báo phiên bản mới.'
  } else {
    Write-Host 'Cùng 3 số phiên bản; chỉ cập nhật build cục bộ, app không nhắc người dùng.'
  }
}
finally {
  try {
    if (-not $completed -and $manifestChanged) {
      if ($manifestExisted) {
        [IO.File]::WriteAllBytes($manifestPath, $manifestBackup)
      } else {
        Remove-Item -LiteralPath $manifestPath -Force
      }
    }
  } finally {
    $env:PATH = $previousPath
    Pop-Location
  }
}
