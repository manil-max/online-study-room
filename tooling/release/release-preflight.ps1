[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('beta', 'stable')][string]$Channel,
  [Parameter(Mandatory)][string]$Tag,
  [Parameter(Mandatory)][string]$ExpectedGitSha,
  [Parameter(Mandatory)][string]$ExpectedMigrationHead,
  [string]$ProjectRef,
  [string]$SupabaseUrl,
  [string]$StagingProjectRef,
  [string]$ProductionProjectRef,
  [string]$ProductionConfirmation,
  [string]$ProductionEvidence,
  # WP-527: kapinin kirik girdiyle sinanabilmesi icin workflow yolu
  # enjekte edilebilir. Bos birakilinca gercek repo dosyasi okunur.
  [string]$ReleaseWorkflowPath,
  # WP-564: deploy kontrati da enjekte edilebilir -- YALNIZ test icin.
  #
  # Sebep: asagidaki head/kontrat kontrolu (satir ~55) Play AAB kontrolunden
  # ONCE kosar. Yerel head production'in onundeyken (migration yazilmis ama
  # henuz uygulanmamis -- mesru ve sik gorulen durum) stable preflight zaten
  # orada duser. WP-527'nin "AAB adimi silinince kapi kirmizi dusmeli"
  # negatifleri boylece AAB yuzunden degil head yuzunden kirmizi oluyordu:
  # release.yml'den Play yolunu tamamen silsen bile testler yesil kalirdi.
  # Testler bu bayrakla head'i tutan gecici bir kontrat verir; olculen sey
  # yeniden AAB adiminin kendisi olur. Gercek yayinda bayrak bos gecilir ve
  # kontrat her zaman repodaki dosyadan okunur.
  [string]$DeployContractPath,
  [switch]$ValidateOnly,
  [string]$EvidenceRoot
)

$ErrorActionPreference = 'Stop'
$guardModule = Join-Path $PSScriptRoot '..\supabase\DeployGuard.psm1'
Import-Module $guardModule -Force

$repoRoot = Get-RepoRoot
$expectedPattern = if ($Channel -eq 'beta') { '^beta-v(?<code>\d+)$' } else { '^v(?<code>\d+)$' }
if ($Tag -notmatch $expectedPattern) {
  throw "Tag '$Tag' does not match channel '$Channel'."
}
$code = [int]$Matches.code
if ($Channel -eq 'beta') {
  $patch = [math]::Floor($code / 100)
  $sequence = $code % 100
  if ($patch -lt 1 -or $sequence -lt 1 -or $sequence -gt 99) {
    throw 'Beta tag must encode patch*100+sequence, with sequence 1-99.'
  }
  $versionName = "1.0.$patch-beta.$sequence"
  $environment = 'staging'
} else {
  if ($code -lt 1) { throw 'Stable tag code must be positive.' }
  $versionName = "1.0.$code"
  $environment = 'production'
}

$actualSha = Get-GitHead -RepoRoot $repoRoot
if ($actualSha -ne $ExpectedGitSha) {
  throw "Git SHA mismatch: local=$actualSha expected=$ExpectedGitSha."
}
$actualHead = Get-LocalMigrationHead -RepoRoot $repoRoot
if ($actualHead -ne $ExpectedMigrationHead) {
  throw "Migration head mismatch: local=$actualHead expected=$ExpectedMigrationHead."
}
$contract = if ([string]::IsNullOrWhiteSpace($DeployContractPath)) {
  Get-DeployContract -RepoRoot $repoRoot
} else {
  if (-not (Test-Path -LiteralPath $DeployContractPath -PathType Leaf)) {
    throw "Deploy contract is missing: $DeployContractPath"
  }
  Get-Content -LiteralPath $DeployContractPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
if ($contract.$environment.migration_head -ne $ExpectedMigrationHead) {
  throw "Release contract rejects migration head $ExpectedMigrationHead for $Channel."
}

# WP-518: yayin notlari GERCEKTEN var mi. v59 bu kontrol olmadigi icin bos
# "Guncelleme notlari" ekraniyla cikti (APK 5 kez indirildi).
Assert-ReleaseNotesEntry -Tag $Tag -Channel $Channel -BuildNumber $code -RepoRoot $repoRoot

# WP-527: Play AAB adimi stable workflow'unda GERCEKTEN duruyor mu.
#
# Sebep tahmin degil, bu repoda iki kez olculdu: kural yaziliydi ama cagiran
# yoktu (release-notes-contract.ps1 hicbir workflow'dan cagrilmiyordu, v59 bos
# "Guncelleme notlari" ekraniyla cikti). Play Console yeni uygulamada APK degil
# AAB ister; adim workflow'dan duserse yayin turu yesil biter ama Play'e
# yuklenecek artefakt hic uretilmemis olur -- ve bunu kimse fark etmez.
if ($Channel -eq 'stable') {
  $workflowPath = if ([string]::IsNullOrWhiteSpace($ReleaseWorkflowPath)) {
    Join-Path $repoRoot '.github\workflows\release.yml'
  } else {
    $ReleaseWorkflowPath
  }
  if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
    throw "Release workflow not found for the Play bundle gate: $workflowPath"
  }
  $workflowSource = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8
  # 🔴 `\S+` KULLANMA: build-name/build-number degerleri `${{ ... }}` ifadesidir
  # ve icinde bosluk vardir; `\S+` sessizce eslesmez ve kapi hep kirmizi kalir.
  if ($workflowSource -notmatch 'flutter build appbundle --release --flavor play --build-name=.+ --build-number=.+ --dart-define-from-file=env\.play\.json') {
    throw 'Stable release must build the Play AAB with the play flavor, release version metadata and the play env file.'
  }
  foreach ($playMarker in @(
    # Play adimlari yalniz stable kanalda kosar (beta sideload kalir).
    "if: needs.preflight.outputs.channel == 'stable'",
    # DISTRIBUTION_CHANNEL Play derlemesinde `play` olmali; ayri env dosyasi.
    "DISTRIBUTION_CHANNEL='play'",
    # LEGAL_BASE_URL Play derlemesinde de bulunmali.
    "assert base['LEGAL_BASE_URL']",
    # APK derlemesinin env.json'u Play adimindan etkilenmemeli.
    'assert again == base',
    # Artefakt + SHA-256 uretimi ve yayinlanmasi.
    'app-play-release.aab',
    'sha256sum app-play-release.aab',
    'release-assets/android/*.aab'
  )) {
    if ($workflowSource -notmatch [regex]::Escape($playMarker)) {
      throw "Stable release workflow is missing the Play AAB path: $playMarker"
    }
  }
}

$result = [ordered]@{
  schema_version = 1
  kind = 'release-preflight'
  tag = $Tag
  channel = $Channel
  environment = $environment
  version_name = $versionName
  build_number = $code
  git_sha = $ExpectedGitSha
  migration_head = $ExpectedMigrationHead
}

if (-not $ValidateOnly) {
  if ([string]::IsNullOrWhiteSpace($ProjectRef) -or [string]::IsNullOrWhiteSpace($SupabaseUrl) -or
      [string]::IsNullOrWhiteSpace($StagingProjectRef) -or [string]::IsNullOrWhiteSpace($ProductionProjectRef)) {
    throw 'Real preflight requires target URL/project-ref and both environment project refs.'
  }
  & (Join-Path $PSScriptRoot 'release-gate.ps1') -Channel $Channel -ProjectRef $ProjectRef -SupabaseUrl $SupabaseUrl `
    -StagingProjectRef $StagingProjectRef -ProductionProjectRef $ProductionProjectRef `
    -ExpectedGitSha $ExpectedGitSha -ExpectedMigrationHead $ExpectedMigrationHead `
    -ProductionConfirmation $ProductionConfirmation -ProductionEvidence $ProductionEvidence -EvidenceRoot $EvidenceRoot
}

$result | ConvertTo-Json -Depth 4
