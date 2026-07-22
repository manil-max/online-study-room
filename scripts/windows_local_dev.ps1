[CmdletBinding()]
param(
  [switch]$BuildOnly
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDirectory = Join-Path $repoRoot 'app'
$environmentPath = Join-Path $appDirectory 'env.json'
$localTemplatePath = Join-Path $appDirectory 'env.local.example.json'

if (-not (Test-Path -LiteralPath $localTemplatePath -PathType Leaf)) {
  throw "Yerel manifest şablonu bulunamadı: $localTemplatePath"
}

# Yerel InMemory manifesti yalnız bu PowerShell oturumu boyunca app/env.json'a
# konur. Mevcut kullanıcı manifestini temp dizininde yedekleyip her çıkışta
# geri getirir; hiçbir secret repo içine veya konsol çıktısına yazılmaz.
$backupPath = Join-Path ([System.IO.Path]::GetTempPath()) ("odak-kampi-env-{0}.json" -f [guid]::NewGuid())
$hadOriginalEnvironment = Test-Path -LiteralPath $environmentPath -PathType Leaf
$localEnvironmentHash = $null
$restoreRequired = $false

try {
  if ($hadOriginalEnvironment) {
    Copy-Item -LiteralPath $environmentPath -Destination $backupPath -Force
  }

  Copy-Item -LiteralPath $localTemplatePath -Destination $environmentPath -Force
  $localEnvironmentHash = (Get-FileHash -LiteralPath $environmentPath -Algorithm SHA256).Hash
  $restoreRequired = $true

  Push-Location $appDirectory
  try {
    if ($BuildOnly) {
      # Windows Flutter toolchain --flavor desteklemez; kanal manifestten gelir.
      & flutter build windows --release --dart-define-from-file=env.json
    }
    else {
      & flutter run -d windows --dart-define-from-file=env.json
    }
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter Windows komutu başarısız oldu (exit code $LASTEXITCODE)."
    }
  }
  finally {
    Pop-Location
  }
}
finally {
  if ($restoreRequired) {
    $currentHash = if (Test-Path -LiteralPath $environmentPath -PathType Leaf) {
      (Get-FileHash -LiteralPath $environmentPath -Algorithm SHA256).Hash
    }
    else {
      $null
    }

    if ($currentHash -ne $localEnvironmentHash) {
      Write-Warning 'env.json bu komut sürerken değişti; veri kaybını önlemek için otomatik geri yükleme yapılmadı.'
      if ($hadOriginalEnvironment) {
        Write-Warning "Önceki manifest güvenli geri yükleme için burada tutuluyor: $backupPath"
      }
    }
    elseif ($hadOriginalEnvironment) {
      Copy-Item -LiteralPath $backupPath -Destination $environmentPath -Force
      Remove-Item -LiteralPath $backupPath -Force
      Write-Output 'Yerel çalışma bitti; önceki env.json geri yüklendi.'
    }
    else {
      Remove-Item -LiteralPath $environmentPath -Force
      Write-Output 'Yerel çalışma bitti; geçici env.json kaldırıldı.'
    }
  }
}
