[CmdletBinding()]
param(
  [string[]]$TestPath = @(),
  [switch]$ConfiguredOnly,
  [switch]$UnconfiguredOnly,
  [string]$FlutterExecutable = 'flutter'
)

$ErrorActionPreference = 'Stop'

if ($ConfiguredOnly -and $UnconfiguredOnly) {
  throw 'ConfiguredOnly and UnconfiguredOnly cannot be used together.'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$appRoot = Join-Path $repoRoot 'app'
$templatePath = Join-Path $appRoot 'env.ci.example.json'
$localEnvPath = Join-Path $appRoot 'env.json'
$firebaseKeys = @(
  'FIREBASE_PROJECT_ID',
  'FIREBASE_ANDROID_API_KEY',
  'FIREBASE_ANDROID_APP_ID',
  'FIREBASE_MESSAGING_SENDER_ID'
)
$baseKeys = @(
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
  'DISTRIBUTION_CHANNEL'
)
$configuredKeys = @($baseKeys + $firebaseKeys)

if (-not (Test-Path -LiteralPath $templatePath)) {
  throw "Candidate manifest template is missing: $templatePath"
}

$template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8 |
  ConvertFrom-Json
$actualKeys = @($template.PSObject.Properties.Name | Sort-Object)
$expectedKeys = @($configuredKeys | Sort-Object)
if (($actualKeys -join "`n") -cne ($expectedKeys -join "`n")) {
  throw 'Candidate manifest must contain exactly the 17 Android release fields.'
}
foreach ($key in $configuredKeys) {
  $value = [string]$template.$key
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Candidate manifest field must not be empty: $key"
  }
  if ($value -match 'REPLACE_WITH') {
    throw "Candidate manifest must use test-only placeholders: $key"
  }
}

$configured = [ordered]@{}
foreach ($key in $configuredKeys) {
  $configured[$key] = [string]$template.$key
}

$gitSha = (& git -C $repoRoot rev-parse HEAD 2>$null | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $gitSha -notmatch '^[0-9a-f]{40}$') {
  throw 'Unable to resolve the candidate git SHA.'
}
$configured['GIT_COMMIT_SHA'] = $gitSha

$migration = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'supabase\migrations') `
  -Filter '*.sql' -File |
  Where-Object Name -Match '^(\d{4})_[a-z0-9_]+\.sql$' |
  Sort-Object Name |
  Select-Object -Last 1
if ($null -eq $migration) {
  throw 'Unable to resolve the local migration head.'
}
$configured['MIGRATION_HEAD'] = $migration.Name.Substring(0, 4)

$unconfigured = [ordered]@{}
foreach ($key in $baseKeys) {
  $unconfigured[$key] = $configured[$key]
}

$temporaryDirectory = Join-Path (
  [IO.Path]::GetTempPath()
) "online-study-room-candidate-$([guid]::NewGuid().ToString('N'))"
$configuredPath = Join-Path $temporaryDirectory 'env.configured.json'
$unconfiguredPath = Join-Path $temporaryDirectory 'env.unconfigured.json'
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$localEnvExisted = Test-Path -LiteralPath $localEnvPath
$localEnvHashBefore = if ($localEnvExisted) {
  (Get-FileHash -LiteralPath $localEnvPath -Algorithm SHA256).Hash
} else {
  $null
}
$results = [Collections.Generic.List[object]]::new()

function Write-ProfileManifest {
  param(
    [Parameter(Mandatory)][Collections.IDictionary]$Manifest,
    [Parameter(Mandatory)][string]$Path
  )

  [IO.File]::WriteAllText(
    $Path,
    (($Manifest | ConvertTo-Json -Depth 4) + [Environment]::NewLine),
    $utf8NoBom
  )
}

function Invoke-CandidateProfile {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$ManifestPath
  )

  $arguments = [Collections.Generic.List[string]]::new()
  $arguments.Add('test')
  foreach ($path in $TestPath) {
    if (-not [string]::IsNullOrWhiteSpace($path)) {
      $arguments.Add($path)
    }
  }
  $arguments.Add("--dart-define-from-file=$ManifestPath")

  Write-Host "Candidate profile '$Name' is running."
  & $FlutterExecutable @arguments
  $exitCode = $LASTEXITCODE
  if ($null -eq $exitCode) { $exitCode = 0 }
  $results.Add([pscustomobject]@{ Name = $Name; ExitCode = $exitCode })
}

[IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
try {
  Write-ProfileManifest -Manifest $configured -Path $configuredPath
  Write-ProfileManifest -Manifest $unconfigured -Path $unconfiguredPath

  Push-Location $appRoot
  try {
    if (-not $UnconfiguredOnly) {
      Invoke-CandidateProfile -Name 'configured-android' `
        -ManifestPath $configuredPath
    }
    if (-not $ConfiguredOnly) {
      Invoke-CandidateProfile -Name 'unconfigured-windows' `
        -ManifestPath $unconfiguredPath
    }
  } finally {
    Pop-Location
  }
} finally {
  if (Test-Path -LiteralPath $temporaryDirectory) {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
  }
}

$localEnvExistsAfter = Test-Path -LiteralPath $localEnvPath
$localEnvHashAfter = if ($localEnvExistsAfter) {
  (Get-FileHash -LiteralPath $localEnvPath -Algorithm SHA256).Hash
} else {
  $null
}
if ($localEnvExisted -ne $localEnvExistsAfter -or
    $localEnvHashBefore -ne $localEnvHashAfter) {
  throw 'Candidate verification changed app/env.json.'
}

$failed = @($results | Where-Object ExitCode -ne 0)
foreach ($result in $results) {
  $status = if ($result.ExitCode -eq 0) { 'PASS' } else { 'FAIL' }
  Write-Host "$($result.Name): $status"
}
if ($failed.Count -gt 0) {
  throw "Candidate verification failed in $($failed.Count) profile(s)."
}

Write-Host "Candidate verification passed in $($results.Count) profile(s)."
