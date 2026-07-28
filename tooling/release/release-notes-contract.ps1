param(
  [Parameter(Mandatory = $true)][string]$UserNotesPath,
  [Parameter(Mandatory = $true)][string]$TechnicalLogPath
)

$ErrorActionPreference = 'Stop'

foreach ($path in @($UserNotesPath, $TechnicalLogPath)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Release-notes source was not found: $path"
  }
}

$userNotes = Get-Content -LiteralPath $UserNotesPath -Raw -Encoding UTF8 |
  ConvertFrom-Json
$technicalLog = Get-Content -LiteralPath $TechnicalLogPath -Raw -Encoding UTF8 |
  ConvertFrom-Json

if (@($userNotes.releases).Count -eq 0) {
  throw 'User-facing release-notes source must contain at least one release.'
}
if (@($technicalLog.releases).Count -eq 0) {
  throw 'Technical release log must contain at least one release.'
}

$forbidden = [regex]::new(
  '(?i)(migration|\bWP-\d+|\bRPCs?\b|\bSQL\b|\b00\d{2}\b)',
  [Text.RegularExpressions.RegexOptions]::CultureInvariant
)
$userTextFields = @(
  'title', 'highlights', 'fixes', 'notes',
  'titleEn', 'highlightsEn', 'fixesEn', 'notesEn'
)

foreach ($release in @($userNotes.releases)) {
  foreach ($field in $userTextFields) {
    $value = $release.$field
    $items = if ($value -is [System.Collections.IEnumerable] -and
      $value -isnot [string]) { @($value) } else { @($value) }
    foreach ($item in $items) {
      $text = [string]$item
      if ($forbidden.IsMatch($text)) {
        throw "User-facing release note contains technical text in build $($release.buildNumber), field '$field': $text"
      }
    }
  }
}

Write-Host "Release-notes contract: $(@($userNotes.releases).Count) user releases checked; technical log kept separate."
