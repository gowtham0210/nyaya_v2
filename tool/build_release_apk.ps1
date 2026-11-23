<#
  Builds the release APK against a named server, and refuses to build against
  one that a phone could not reach (localhost, a LAN address or plain http).

    .\tool\build_release_apk.ps1 -ApiUrl https://staging-api.deepwebstudio.dev

  The key for crash reports is read from the git-ignored .dart-defines.local.json
  when that file exists. The APK is signed with the debug key until a release
  keystore is set up in android/app/build.gradle.kts.
#>
param(
  [Parameter(Mandatory = $true)][string]$ApiUrl
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

$uri = $null
if (-not [Uri]::TryCreate($ApiUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
  throw "ApiUrl must be a full https:// address (got '$ApiUrl'). Release builds block plain http."
}
if ($uri.Host -match '^(localhost|127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)') {
  throw "ApiUrl '$ApiUrl' is a local address; a phone cannot reach it. Use the hosted API."
}

Write-Host "Checking $ApiUrl ..."
try {
  $health = Invoke-WebRequest -UseBasicParsing -Uri "$($ApiUrl.TrimEnd('/'))/v1/daily-tips/today?language=en" -TimeoutSec 20
  Write-Host "  daily tips endpoint: HTTP $($health.StatusCode) $($health.Content)"
} catch {
  throw "The server does not serve /v1/daily-tips/today ($($_.Exception.Message)). Deploy the backend first, or Daily Tips will show an error in the app."
}

$args = @('build', 'apk', '--release', "--dart-define=NYAYA_API_URL=$ApiUrl")
if (Test-Path '.dart-defines.local.json') { $args += '--dart-define-from-file=.dart-defines.local.json' }
& flutter @args
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }

Write-Host "`nBuilt: build\app\outputs\flutter-apk\app-release.apk"
