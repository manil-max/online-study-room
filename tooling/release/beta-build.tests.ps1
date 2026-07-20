$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$gradlePath = Join-Path $repoRoot 'app\android\app\build.gradle.kts'
$buildScriptPath = Join-Path $repoRoot 'tooling\release\beta-build.ps1'
$gradle = Get-Content -LiteralPath $gradlePath -Raw -Encoding UTF8
$buildScript = Get-Content -LiteralPath $buildScriptPath -Raw -Encoding UTF8

$betaBlock = [regex]::Match(
  $gradle,
  'create\("beta"\)\s*\{(?<body>[\s\S]*?)\n\s*\}',
  [Text.RegularExpressions.RegexOptions]::CultureInvariant
)
if (-not $betaBlock.Success) { throw 'Android beta flavor block was not found.' }
if ($betaBlock.Groups['body'].Value -match 'versionNameSuffix') {
  throw 'Beta flavor must not append a second version-name suffix.'
}
if ($betaBlock.Groups['body'].Value -notmatch 'applicationIdSuffix\s*=\s*"\.beta"') {
  throw 'Beta flavor package isolation is missing.'
}
if ($buildScript -notmatch '06-apk-identity' -or
    $buildScript -notmatch '07-apk-signature' -or
    $buildScript -notmatch '08-package-evidence-artifact') {
  throw 'Beta artifact identity/signature/evidence gates are incomplete.'
}
if ($buildScript -match 'Write-DeployJson\s+-Value\s+\$buildManifest\s+-Path\s+\$localEnvPath') {
  throw 'Beta build must never overwrite app/env.json.'
}

Write-Host 'Beta build contract tests: 4 passed.'
