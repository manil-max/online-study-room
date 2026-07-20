[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ProjectRef,
  [Parameter(Mandatory)][string]$SupabaseUrl,
  [Parameter(Mandatory)][string]$StagingProjectRef,
  [Parameter(Mandatory)][string]$ProductionProjectRef,
  [Parameter(Mandatory)][string]$ExpectedGitSha,
  [Parameter(Mandatory)][string]$ExpectedMigrationHead,
  [Parameter(Mandatory)][ValidatePattern('^\d+$')][string]$BuildNumber,
  [string]$EvidenceRoot
)

$ErrorActionPreference = 'Stop'
$guardModule = Join-Path $PSScriptRoot '..\supabase\DeployGuard.psm1'
Import-Module $guardModule -Force

$repoRoot = Get-RepoRoot
$appRoot = Join-Path $repoRoot 'app'
$envPath = Join-Path $appRoot 'env.json'
$evidenceDirectory = New-EvidenceDirectory -Kind 'staging-beta-build' -EvidenceRoot $EvidenceRoot -RepoRoot $repoRoot
$startedAt = (Get-Date).ToUniversalTime()
$status = 'failed'
$failure = $null
$steps = [Collections.Generic.List[string]]::new()
$artifact = $null
$anonKey = $env:STAGING_SUPABASE_ANON_KEY

function Invoke-FlutterEvidence {
  param([string[]]$Arguments, [string]$Label)
  $steps.Add($Label)
  Invoke-EvidenceCommand -Executable 'flutter' -Arguments $Arguments -EvidenceDirectory $evidenceDirectory -Label $Label -SensitiveValues @($anonKey) | Out-Null
}

Push-Location $repoRoot
try {
  if (Test-Path -LiteralPath $envPath) {
    throw 'app/env.json already exists; refusing to overwrite a real local environment file.'
  }
  if ([string]::IsNullOrWhiteSpace($anonKey)) {
    throw 'STAGING_SUPABASE_ANON_KEY must come from the staging environment secret store.'
  }

  & (Join-Path $PSScriptRoot 'release-gate.ps1') -Channel beta -ProjectRef $ProjectRef -SupabaseUrl $SupabaseUrl -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef -ExpectedGitSha $ExpectedGitSha -ExpectedMigrationHead $ExpectedMigrationHead -EvidenceRoot $EvidenceRoot

  $buildManifest = [ordered]@{
    CHANNEL = 'beta'
    APP_ENVIRONMENT = 'staging'
    ALLOW_IN_MEMORY = 'false'
    SUPABASE_URL = $SupabaseUrl
    SUPABASE_ANON_KEY = $anonKey
    SUPABASE_PROJECT_REF = $ProjectRef
    STAGING_SUPABASE_PROJECT_REF = $StagingProjectRef
    PRODUCTION_SUPABASE_PROJECT_REF = $ProductionProjectRef
    GIT_COMMIT_SHA = $ExpectedGitSha
    MIGRATION_HEAD = $ExpectedMigrationHead
    DISTRIBUTION_CHANNEL = 'githubBeta'
  }
  Write-DeployJson -Value $buildManifest -Path $envPath

  Push-Location $appRoot
  try {
    Invoke-FlutterEvidence -Arguments @('pub', 'get') -Label '01-flutter-pub-get'
    Invoke-FlutterEvidence -Arguments @('analyze') -Label '02-flutter-analyze'
    Invoke-FlutterEvidence -Arguments @('test', 'test/core/current_build_manifest_gate_test.dart', '--dart-define-from-file=env.json', '--dart-define=ENFORCE_CURRENT_BUILD_MANIFEST=true') -Label '03-build-manifest-gate'
    Invoke-FlutterEvidence -Arguments @('test', '--dart-define-from-file=env.json') -Label '04-flutter-test'
    Invoke-FlutterEvidence -Arguments @('build', 'apk', '--release', '--flavor', 'beta', "--build-number=$BuildNumber", '--dart-define-from-file=env.json') -Label '05-beta-apk'
  } finally {
    Pop-Location
  }

  $apk = Join-Path $appRoot 'build\app\outputs\flutter-apk\app-beta-release.apk'
  if (-not (Test-Path -LiteralPath $apk)) { throw 'Beta APK was not produced.' }
  $artifact = [ordered]@{
    name = 'app-beta-release.apk'
    bytes = (Get-Item -LiteralPath $apk).Length
    sha256 = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    build_number = $BuildNumber
  }
  $status = 'success'
} catch {
  $failure = $_.Exception.Message
  throw
} finally {
  if (Test-Path -LiteralPath $envPath) {
    Remove-Item -LiteralPath $envPath -Force
  }
  $manifest = [ordered]@{
    schema_version = 1
    kind = 'beta-build'
    channel = 'beta'
    environment = 'staging'
    status = $status
    project_ref = $ProjectRef
    git_sha = $ExpectedGitSha
    migration_head = $ExpectedMigrationHead
    started_at_utc = $startedAt.ToString('o')
    completed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    steps = @($steps)
    artifact = $artifact
    failure = Protect-DeployText -Text $failure -SensitiveValues @($anonKey)
  }
  Write-DeployJson -Value $manifest -Path (Join-Path $evidenceDirectory 'beta-build-manifest.json')
  Write-Host "Evidence: $evidenceDirectory"
  Pop-Location
}
