[CmdletBinding()]
param(
  [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'app\build\windows_shell_smoke.png')
)

# Eski adla çağrılan otomasyonları korur; yeni hızlı kontrol açık olan
# uygulamaya bağlanır ve aynı zamanda makine-okunur kanıt üretir.
& (Join-Path $PSScriptRoot 'windows_fast_smoke.ps1') -NoLaunch -NoForeground -OutputPath $OutputPath
exit $LASTEXITCODE
