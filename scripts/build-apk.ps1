param(
    [ValidateSet('debug', 'release')]
    [string] $Mode = 'debug'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $projectRoot

try {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'Flutter was not found. Install Flutter 3.47.1 and add its bin folder to PATH.'
    }

    flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter pub get failed.'
    }

    $flutterArgs = @('build', 'apk', "--$Mode")
    if ($env:GOOGLE_SERVER_CLIENT_ID) {
        $flutterArgs += "--dart-define=GOOGLE_SERVER_CLIENT_ID=$($env:GOOGLE_SERVER_CLIENT_ID)"
    }
    if ($env:GOOGLE_IOS_CLIENT_ID) {
        $flutterArgs += "--dart-define=GOOGLE_IOS_CLIENT_ID=$($env:GOOGLE_IOS_CLIENT_ID)"
    }

    flutter @flutterArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter failed to build the $Mode APK."
    }

    $apkName = if ($Mode -eq 'debug') { 'app-debug.apk' } else { 'app-release.apk' }
    $apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\$apkName"
    Write-Host "APK created: $apkPath"
}
finally {
    Pop-Location
}
