[CmdletBinding()]
param(
  [string]$ProjectName = 'online-study-room-staging',
  [Parameter(Mandatory)][string]$OrganizationId,
  [string]$Region = 'ap-northeast-1',
  [string]$Size = 'nano',
  [string]$NodePath
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cliEntry = Join-Path $repoRoot 'node_modules\supabase\dist\supabase.js'

if ([string]::IsNullOrWhiteSpace($NodePath)) {
  $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
  if ($nodeCommand) { $NodePath = $nodeCommand.Source }
}
if ([string]::IsNullOrWhiteSpace($NodePath) -or -not (Test-Path -LiteralPath $NodePath)) {
  throw 'Node.js bulunamadı. -NodePath ile mutlak node.exe yolunu verin.'
}
if (-not (Test-Path -LiteralPath $cliEntry)) {
  throw 'Pinli Supabase CLI bulunamadı. Önce pnpm install --frozen-lockfile çalıştırın.'
}
if ($ProjectName -ne 'online-study-room-staging') {
  throw 'Bu yardımcı yalnız online-study-room-staging projesini oluşturabilir.'
}
if ($Region -ne 'ap-northeast-1') {
  throw 'Staging bölgesi production parity için ap-northeast-1 olmalıdır.'
}
if ($Size -ne 'nano') {
  throw 'Bu yardımcı yalnız en küçük nano staging boyutuna izin verir.'
}

$previousErrorActionPreference = $ErrorActionPreference
try {
  $ErrorActionPreference = 'SilentlyContinue'
  $projectsJson = & $NodePath $cliEntry projects list --output json 2>$null
  $projectsListExitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousErrorActionPreference
}
if ($projectsListExitCode -ne 0) {
  throw 'Supabase CLI oturumu doğrulanamadı.'
}
$projects = @($projectsJson | ConvertFrom-Json)
$existing = @($projects | Where-Object { $_.name -eq $ProjectName })
if ($existing.Count -gt 0) {
  Write-Host 'Staging projesi zaten var; yeni proje oluşturulmadı.' -ForegroundColor Yellow
  Write-Host "Project ref: $($existing[0].ref)"
  exit 0
}

Write-Host ''
Write-Host 'Oluşturulacak Supabase projesi:' -ForegroundColor Cyan
Write-Host "  Ad:     $ProjectName"
Write-Host "  Bölge:  $Region"
Write-Host "  Boyut:  $Size"
Write-Host '  Amaç:   yalnız staging/beta; production verisi kopyalanmaz'
Write-Host ''
$confirmation = Read-Host 'Devam etmek için STAGING yazın'
if ($confirmation -cne 'STAGING') {
  throw 'Kullanıcı proje oluşturmayı iptal etti.'
}

$securePassword = Read-Host 'Yeni staging DB parolası (production parolasını kullanmayın)' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$plainPassword = $null
try {
  $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
  if ([string]::IsNullOrWhiteSpace($plainPassword)) {
    throw 'Staging DB parolası boş olamaz.'
  }
  & $NodePath $cliEntry projects create $ProjectName `
    --org-id $OrganizationId `
    --db-password $plainPassword `
    --region $Region `
    --size $Size `
    --output json
  if ($LASTEXITCODE -ne 0) {
    throw "Supabase proje oluşturma başarısız oldu (exit $LASTEXITCODE)."
  }
} finally {
  $plainPassword = $null
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
  $securePassword.Dispose()
}

Write-Host ''
Write-Host 'Staging proje oluşturma isteği başarıyla tamamlandı.' -ForegroundColor Green
Write-Host 'Bu pencereyi kapatmadan önce DB parolasını parola yöneticinize kaydettiğinizden emin olun.'
