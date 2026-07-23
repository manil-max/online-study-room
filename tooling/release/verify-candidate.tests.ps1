$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$templatePath = Join-Path $repoRoot 'app\env.ci.example.json'
$scriptPath = Join-Path $repoRoot 'tooling\release\verify-candidate.ps1'
$gitignorePath = Join-Path $repoRoot '.gitignore'
$expectedConfiguredKeys = @(
  'CHANNEL',
  'APP_ENVIRONMENT',
  'ALLOW_IN_MEMORY',
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'SUPABASE_PROJECT_REF',
  'STAGING_SUPABASE_PROJECT_REF',
  'PRODUCTION_SUPABASE_PROJECT_REF',
  'GIT_COMMIT_SHA',
  'MIGRATION_HEAD',
  'APP_VERSION_NAME',
  'APP_BUILD_NUMBER',
  'DISTRIBUTION_CHANNEL',
  'FIREBASE_PROJECT_ID',
  'FIREBASE_ANDROID_API_KEY',
  'FIREBASE_ANDROID_APP_ID',
  'FIREBASE_MESSAGING_SENDER_ID'
)

$template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8 |
  ConvertFrom-Json
$actualKeys = @($template.PSObject.Properties.Name | Sort-Object)
$expectedKeys = @($expectedConfiguredKeys | Sort-Object)
if (($actualKeys -join "`n") -cne ($expectedKeys -join "`n")) {
  throw 'Configured candidate template does not match the 17-field contract.'
}
foreach ($key in $expectedConfiguredKeys) {
  $value = [string]$template.$key
  if ([string]::IsNullOrWhiteSpace($value) -or $value -match 'REPLACE_WITH') {
    throw "Candidate template is not runnable with safe placeholders: $key"
  }
}

$gitignore = Get-Content -LiteralPath $gitignorePath -Raw -Encoding UTF8
if ($gitignore -notmatch '(?m)^!\*\*/env\.\*\.example\.json\s*$') {
  throw 'Example env files must remain explicitly trackable.'
}

$temporaryDirectory = Join-Path (
  [IO.Path]::GetTempPath()
) "online-study-room-candidate-test-$([guid]::NewGuid().ToString('N'))"
$fakeFlutter = Join-Path $temporaryDirectory 'fake-flutter.ps1'
$logPath = Join-Path $temporaryDirectory 'profiles.log'
[IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
try {
  @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Remaining)
$define = $Remaining | Where-Object { $_ -like '--dart-define-from-file=*' }
if (@($define).Count -ne 1) { throw 'Expected one define manifest.' }
$path = $define.Substring('--dart-define-from-file='.Length)
$manifest = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
$keys = @($manifest.PSObject.Properties.Name)
$firebaseCount = @($keys | Where-Object { $_ -like 'FIREBASE_*' }).Count
"$($keys.Count)|$firebaseCount|$($Remaining -join ' ')" |
  Add-Content -LiteralPath $env:CANDIDATE_VERIFY_TEST_LOG -Encoding UTF8
exit 0
'@ | Set-Content -LiteralPath $fakeFlutter -Encoding UTF8

  $env:CANDIDATE_VERIFY_TEST_LOG = $logPath
  & $scriptPath -FlutterExecutable $fakeFlutter `
    -TestPath @('test/widget_test.dart')
  if ($LASTEXITCODE -ne 0) {
    throw 'Candidate verification mock run failed.'
  }

  $profiles = @(Get-Content -LiteralPath $logPath -Encoding UTF8)
  if ($profiles.Count -ne 2) {
    throw 'Candidate verification must run exactly two profiles by default.'
  }
  if ($profiles[0] -notmatch '^17\|4\|test test/widget_test\.dart ') {
    throw 'Configured profile is not the 17-field Android profile.'
  }
  if ($profiles[1] -notmatch '^13\|0\|test test/widget_test\.dart ') {
    throw 'Unconfigured profile is not the 13-field Windows profile.'
  }
} finally {
  Remove-Item Env:CANDIDATE_VERIFY_TEST_LOG -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $temporaryDirectory) {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
  }
}

Write-Host 'Candidate verification contract tests: 6 passed.'
