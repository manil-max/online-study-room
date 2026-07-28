$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$contractPath = Join-Path $PSScriptRoot 'release-notes-contract.ps1'
$userNotesPath = Join-Path $repoRoot 'app\assets\release_notes.json'
$technicalLogPath = Join-Path $PSScriptRoot 'release_notes_technical.json'

& $contractPath -UserNotesPath $userNotesPath -TechnicalLogPath $technicalLogPath |
  Out-Null

$technicalLog = Get-Content -LiteralPath $technicalLogPath -Raw -Encoding UTF8 |
  ConvertFrom-Json
$v54 = @($technicalLog.releases | Where-Object { $_.buildNumber -eq 54 })
if ($v54.Count -ne 1 -or (($v54[0].notes -join "`n") -notmatch '(?i)migration')) {
  throw 'Technical log must retain the v54 internal migration history.'
}

$temporaryPath = Join-Path ([IO.Path]::GetTempPath()) (
  "online-study-room-release-notes-$([guid]::NewGuid().ToString('N')).json"
)
try {
  $tampered = Get-Content -LiteralPath $userNotesPath -Raw -Encoding UTF8
  $tampered = $tampered -replace '"highlights":\s*\[', '"highlights": ["migration", '
  Set-Content -LiteralPath $temporaryPath -Value $tampered -Encoding UTF8

  $failed = $false
  try {
    & $contractPath -UserNotesPath $temporaryPath -TechnicalLogPath $technicalLogPath |
      Out-Null
  } catch {
    $failed = $true
  }
  if (-not $failed) {
    throw 'Forbidden user-facing technical text must fail the contract.'
  }
} finally {
  if (Test-Path -LiteralPath $temporaryPath) {
    Remove-Item -LiteralPath $temporaryPath -Force
  }
}

Write-Host 'Release-notes contract tests: 2 passed.'
