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
# WP-773 dersi: uygulama ici ekranin testi (`release_notes_test.dart`) STABLE
# notlarinda commit/backend/project-ref/supabase kelimelerini de yasaklar; v78
# notu 'commit listesi' yuzunden CI'da dustu, bu sozlesme ise gecmisti. Iki
# kapi artik ayni listeyi kullanir. Beta notlari o ekranda gorunmez; eski beta
# girdileri (4303 gibi) 'staging backend' der ve dokunulmaz. Eski stable notlar
# da dokunulmaz (v1 'Supabase' der; uygulama ici test yalniz ekranda gorunen son
# kartlari olcer): kural v78'den itibaren gecerli.
$stableForbidden = [regex]::new(
  '(?i)(commit|backend|project[- ]?ref|supabase)',
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
      if ($release.channel -eq 'stable' -and [int]$release.buildNumber -ge 78 -and $stableForbidden.IsMatch($text)) {
        throw "Stable release note would fail the in-app leak test (release_notes_test.dart) in build $($release.buildNumber), field '$field': $text"
      }
    }
  }
}

Write-Host "Release-notes contract: $(@($userNotes.releases).Count) user releases checked; technical log kept separate."
