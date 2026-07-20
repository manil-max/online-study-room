[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ProjectRef,
  [Parameter(Mandatory)][string]$SupabaseUrl,
  [Parameter(Mandatory)][string]$StagingProjectRef,
  [Parameter(Mandatory)][string]$ProductionProjectRef,
  [Parameter(Mandatory)][string]$ExpectedGitSha,
  [Parameter(Mandatory)][string]$ExpectedMigrationHead,
  [ValidatePattern('^\d+\.\d+\.\d+-beta\.\d+$')][string]$VersionName = '1.0.42-beta.1',
  [Parameter(Mandatory)][ValidatePattern('^\d+$')][string]$BuildNumber,
  [string]$EvidenceRoot
)

$ErrorActionPreference = 'Stop'
$guardModule = Join-Path $PSScriptRoot '..\supabase\DeployGuard.psm1'
Import-Module $guardModule -Force

$repoRoot = Get-RepoRoot
$appRoot = Join-Path $repoRoot 'app'
$localEnvPath = Join-Path $appRoot 'env.json'
$evidenceDirectory = New-EvidenceDirectory -Kind 'staging-beta-build' -EvidenceRoot $EvidenceRoot -RepoRoot $repoRoot
$temporaryEnvDirectory = Join-Path ([IO.Path]::GetTempPath()) "online-study-room-beta-$([guid]::NewGuid().ToString('N'))"
$temporaryEnvPath = Join-Path $temporaryEnvDirectory 'env.staging-build.json'
$startedAt = (Get-Date).ToUniversalTime()
$status = 'failed'
$failure = $null
$steps = [Collections.Generic.List[string]]::new()
$artifact = $null
$anonKey = $env:STAGING_SUPABASE_ANON_KEY
$localEnvExisted = Test-Path -LiteralPath $localEnvPath
$localEnvHashBefore = if ($localEnvExisted) {
  (Get-FileHash -LiteralPath $localEnvPath -Algorithm SHA256).Hash.ToLowerInvariant()
} else { $null }
$localEnvPreserved = $false

function Invoke-FlutterEvidence {
  param([string[]]$Arguments, [string]$Label)
  $steps.Add($Label)
  Invoke-EvidenceCommand -Executable 'flutter' -Arguments $Arguments -EvidenceDirectory $evidenceDirectory -Label $Label -SensitiveValues @($anonKey) | Out-Null
}

function Resolve-AndroidBuildTool {
  param([Parameter(Mandatory)][string]$ToolName)

  foreach ($sdkRoot in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT) | Select-Object -Unique) {
    if ([string]::IsNullOrWhiteSpace($sdkRoot)) { continue }
    $buildToolsRoot = Join-Path $sdkRoot 'build-tools'
    if (-not (Test-Path -LiteralPath $buildToolsRoot)) { continue }
    $match = Get-ChildItem -LiteralPath $buildToolsRoot -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -eq $ToolName -or $_.Name -eq "$ToolName.exe" -or $_.Name -eq "$ToolName.bat" } |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if ($match) { return $match.FullName }
  }
  throw "Android build tool was not found: $ToolName"
}

Push-Location $repoRoot
try {
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
    APP_VERSION_NAME = $VersionName
    APP_BUILD_NUMBER = $BuildNumber
  }
  [IO.Directory]::CreateDirectory($temporaryEnvDirectory) | Out-Null
  Write-DeployJson -Value $buildManifest -Path $temporaryEnvPath
  $defineFromFile = "--dart-define-from-file=$temporaryEnvPath"

  Push-Location $appRoot
  try {
    Invoke-FlutterEvidence -Arguments @('pub', 'get') -Label '01-flutter-pub-get'
    Invoke-FlutterEvidence -Arguments @('analyze') -Label '02-flutter-analyze'
    Invoke-FlutterEvidence -Arguments @('test', 'test/core/current_build_manifest_gate_test.dart', $defineFromFile, '--dart-define=ENFORCE_CURRENT_BUILD_MANIFEST=true') -Label '03-build-manifest-gate'
    Invoke-FlutterEvidence -Arguments @('test', $defineFromFile) -Label '04-flutter-test'
    Invoke-FlutterEvidence -Arguments @('build', 'apk', '--release', '--flavor', 'beta', "--build-name=$VersionName", "--build-number=$BuildNumber", $defineFromFile) -Label '05-beta-apk'
  } finally {
    Pop-Location
  }

  $apk = Join-Path $appRoot 'build\app\outputs\flutter-apk\app-beta-release.apk'
  if (-not (Test-Path -LiteralPath $apk)) { throw 'Beta APK was not produced.' }
  $aapt = Resolve-AndroidBuildTool -ToolName 'aapt'
  $steps.Add('06-apk-identity')
  $badging = Invoke-EvidenceCommand -Executable $aapt -Arguments @('dump', 'badging', $apk) -EvidenceDirectory $evidenceDirectory -Label '06-apk-identity' -SensitiveValues @($anonKey)
  $expectedIdentity = "package: name='com.manilmax.online_study_room.beta' versionCode='$BuildNumber' versionName='$VersionName'"
  if (-not $badging.Contains($expectedIdentity)) {
    throw 'Beta APK package/version identity does not match the release manifest.'
  }

  $apksigner = Resolve-AndroidBuildTool -ToolName 'apksigner'
  $steps.Add('07-apk-signature')
  $signature = Invoke-EvidenceCommand -Executable $apksigner -Arguments @('verify', '--verbose', '--print-certs', $apk) -EvidenceDirectory $evidenceDirectory -Label '07-apk-signature' -SensitiveValues @($anonKey)
  if (-not $signature.Contains('Verified using v2 scheme (APK Signature Scheme v2): true')) {
    throw 'Beta APK v2 signature verification failed.'
  }

  $artifactName = "online-study-room-beta-$VersionName-build$BuildNumber.apk"
  $evidenceApk = Join-Path $evidenceDirectory $artifactName
  $steps.Add('08-package-evidence-artifact')
  Copy-Item -LiteralPath $apk -Destination $evidenceApk
  $artifact = [ordered]@{
    name = $artifactName
    bytes = (Get-Item -LiteralPath $evidenceApk).Length
    sha256 = (Get-FileHash -LiteralPath $evidenceApk -Algorithm SHA256).Hash.ToLowerInvariant()
    version_name = $VersionName
    build_number = $BuildNumber
  }
  $status = 'success'
} catch {
  $failure = $_.Exception.Message
  throw
} finally {
  if (Test-Path -LiteralPath $temporaryEnvPath) {
    Remove-Item -LiteralPath $temporaryEnvPath -Force
  }
  if (Test-Path -LiteralPath $temporaryEnvDirectory) {
    Remove-Item -LiteralPath $temporaryEnvDirectory -Force
  }
  $localEnvExistsAfter = Test-Path -LiteralPath $localEnvPath
  $localEnvHashAfter = if ($localEnvExistsAfter) {
    (Get-FileHash -LiteralPath $localEnvPath -Algorithm SHA256).Hash.ToLowerInvariant()
  } else { $null }
  $localEnvPreserved = $localEnvExisted -eq $localEnvExistsAfter -and $localEnvHashBefore -eq $localEnvHashAfter
  if (-not $localEnvPreserved) {
    $status = 'failed'
    $failure = 'Existing app/env.json preservation check failed.'
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
    version_name = $VersionName
    build_number = $BuildNumber
    local_env_preserved = $localEnvPreserved
    started_at_utc = $startedAt.ToString('o')
    completed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    steps = @($steps)
    artifact = $artifact
    failure = Protect-DeployText -Text $failure -SensitiveValues @($anonKey)
  }
  Write-DeployJson -Value $manifest -Path (Join-Path $evidenceDirectory 'beta-build-manifest.json')
  Write-Host "Evidence: $evidenceDirectory"
  Pop-Location
  if (-not $localEnvPreserved) {
    throw 'Existing app/env.json preservation check failed.'
  }
}
