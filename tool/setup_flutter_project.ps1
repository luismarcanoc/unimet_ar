$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter no esta disponible en PATH. Instala Flutter o agrega flutter\bin al PATH y vuelve a ejecutar este script."
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$backup = Join-Path $env:TEMP ("unimet_ar_backup_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $backup | Out-Null

Copy-Item -LiteralPath (Join-Path $root "lib\main.dart") -Destination (Join-Path $backup "main.dart")
$salonCsvSource = Join-Path $root "lib\salon_csv.dart"
if (Test-Path $salonCsvSource) {
  Copy-Item -LiteralPath $salonCsvSource -Destination (Join-Path $backup "salon_csv.dart")
}
Copy-Item -LiteralPath (Join-Path $root "pubspec.yaml") -Destination (Join-Path $backup "pubspec.yaml")
Copy-Item -LiteralPath (Join-Path $root "analysis_options.yaml") -Destination (Join-Path $backup "analysis_options.yaml")
Copy-Item -LiteralPath (Join-Path $root "README.md") -Destination (Join-Path $backup "README.md")

$iosBackup = Join-Path $backup "ios_custom"
New-Item -ItemType Directory -Path $iosBackup | Out-Null
$iosCustomFiles = @(
  "ios\Runner\AppDelegate.swift",
  "ios\Runner\NativeARView.swift",
  "ios\Runner.xcodeproj\project.pbxproj"
)
foreach ($relativePath in $iosCustomFiles) {
  $source = Join-Path $root $relativePath
  if (Test-Path $source) {
    Copy-Item -LiteralPath $source -Destination (Join-Path $iosBackup ([IO.Path]::GetFileName($source)))
  }
}

$markerAsset = Join-Path $root "ios\Runner\Assets.xcassets\TestARMarker.imageset"
if (Test-Path $markerAsset) {
  Copy-Item -LiteralPath $markerAsset -Destination (Join-Path $iosBackup "TestARMarker.imageset") -Recurse
}

Push-Location $root
try {
  flutter create --platforms android,ios --project-name unimet_ar .

  Copy-Item -LiteralPath (Join-Path $backup "main.dart") -Destination (Join-Path $root "lib\main.dart") -Force
  $salonCsvBackup = Join-Path $backup "salon_csv.dart"
  if (Test-Path $salonCsvBackup) {
    Copy-Item -LiteralPath $salonCsvBackup -Destination (Join-Path $root "lib\salon_csv.dart") -Force
  }
  Copy-Item -LiteralPath (Join-Path $backup "pubspec.yaml") -Destination (Join-Path $root "pubspec.yaml") -Force
  Copy-Item -LiteralPath (Join-Path $backup "analysis_options.yaml") -Destination (Join-Path $root "analysis_options.yaml") -Force
  Copy-Item -LiteralPath (Join-Path $backup "README.md") -Destination (Join-Path $root "README.md") -Force

  $appDelegateBackup = Join-Path $iosBackup "AppDelegate.swift"
  if (Test-Path $appDelegateBackup) {
    Copy-Item -LiteralPath $appDelegateBackup -Destination (Join-Path $root "ios\Runner\AppDelegate.swift") -Force
  }
  $nativeArBackup = Join-Path $iosBackup "NativeARView.swift"
  if (Test-Path $nativeArBackup) {
    Copy-Item -LiteralPath $nativeArBackup -Destination (Join-Path $root "ios\Runner\NativeARView.swift") -Force
  }
  $xcodeProjectBackup = Join-Path $iosBackup "project.pbxproj"
  if (Test-Path $xcodeProjectBackup) {
    Copy-Item -LiteralPath $xcodeProjectBackup -Destination (Join-Path $root "ios\Runner.xcodeproj\project.pbxproj") -Force
  }
  $markerAssetBackup = Join-Path $iosBackup "TestARMarker.imageset"
  $markerAssetDestination = Join-Path $root "ios\Runner\Assets.xcassets\TestARMarker.imageset"
  if ((Test-Path $markerAssetBackup) -and -not (Test-Path $markerAssetDestination)) {
    Copy-Item -LiteralPath $markerAssetBackup -Destination $markerAssetDestination -Recurse -Force
  }

  $androidManifest = Join-Path $root "android\app\src\main\AndroidManifest.xml"
  if (Test-Path $androidManifest) {
    $manifestText = Get-Content -LiteralPath $androidManifest -Raw
    if ($manifestText -notmatch "android.permission.CAMERA") {
      $manifestText = $manifestText -replace "<manifest([^>]*)>", "<manifest`$1>`n    <uses-permission android:name=`"android.permission.CAMERA`" />"
    }
    if ($manifestText -notmatch "android.permission.ACCESS_COARSE_LOCATION") {
      $manifestText = $manifestText -replace "<manifest([^>]*)>", "<manifest`$1>`n    <uses-permission android:name=`"android.permission.ACCESS_COARSE_LOCATION`" />"
    }
    if ($manifestText -notmatch "android.permission.ACCESS_FINE_LOCATION") {
      $manifestText = $manifestText -replace "<manifest([^>]*)>", "<manifest`$1>`n    <uses-permission android:name=`"android.permission.ACCESS_FINE_LOCATION`" />"
    }
    Set-Content -LiteralPath $androidManifest -Value $manifestText
  }

  $infoPlist = Join-Path $root "ios\Runner\Info.plist"
  if (Test-Path $infoPlist) {
    $plistText = Get-Content -LiteralPath $infoPlist -Raw
    if ($plistText -notmatch "NSCameraUsageDescription") {
      $cameraPermission = "`t<key>NSCameraUsageDescription</key>`n`t<string>La camara se usa para mostrar la guia AR sobre el entorno.</string>`n"
      $rootDictIndex = $plistText.IndexOf("<dict>")
      if ($rootDictIndex -ge 0) {
        $insertAt = $rootDictIndex + "<dict>".Length
        $plistText = $plistText.Insert($insertAt, "`n" + $cameraPermission)
      }
    }
    if ($plistText -notmatch "NSLocationWhenInUseUsageDescription") {
      $locationPermission = "`t<key>NSLocationWhenInUseUsageDescription</key>`n`t<string>Tu ubicacion se usa para marcar puntos de interes y guiarte hacia ellos.</string>`n"
      $rootDictIndex = $plistText.IndexOf("<dict>")
      if ($rootDictIndex -ge 0) {
        $insertAt = $rootDictIndex + "<dict>".Length
        $plistText = $plistText.Insert($insertAt, "`n" + $locationPermission)
      }
    }
    Set-Content -LiteralPath $infoPlist -Value $plistText
  }

  flutter pub get
  Write-Host "Proyecto Flutter listo. Ejecuta: flutter run"
}
finally {
  Pop-Location
  Remove-Item -LiteralPath $backup -Recurse -Force
}
