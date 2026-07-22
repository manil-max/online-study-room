[CmdletBinding()]
param(
  [string]$ExecutablePath,
  [string]$OutputPath,
  [ValidateRange(1, 10)]
  [int]$TimeoutSeconds = 10,
  [switch]$NoLaunch,
  [switch]$CloseAfter,
  [switch]$NoForeground,
  [switch]$DismissInitialDialog,
  [ValidateRange(0, 2000)]
  [int]$PostInteractionDelayMs = 300
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ExecutablePath)) {
  $ExecutablePath = Join-Path $repoRoot 'app\build\windows\x64\runner\Release\online_study_room.exe'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $repoRoot 'app\build\windows_fast_smoke.png'
}

$ExecutablePath = [System.IO.Path]::GetFullPath($ExecutablePath)
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$manifestPath = [System.IO.Path]::ChangeExtension($OutputPath, '.json')
$processName = [System.IO.Path]::GetFileNameWithoutExtension($ExecutablePath)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WindowsFastSmoke {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll", SetLastError=true)] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

# PowerShell DPI-aware değilse GetWindowRect sanal koordinat döndürebilir.
[void][WindowsFastSmoke]::SetProcessDPIAware()

function Get-VisibleAppProcess {
  param([string]$Name)

  Get-Process -Name $Name -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Refresh()
      $_.MainWindowHandle -ne 0 -and [WindowsFastSmoke]::IsWindowVisible($_.MainWindowHandle)
    } |
    Select-Object -First 1
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$startedBySmoke = $false
$process = Get-VisibleAppProcess -Name $processName

try {
  if (-not $process) {
    if ($NoLaunch) {
      throw "Gorunur '$processName' penceresi bulunamadi. Uygulamayi once acin veya -NoLaunch parametresini kaldirin."
    }
    if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
      throw "Release EXE bulunamadi: $ExecutablePath. Once Windows release build alin veya -ExecutablePath ile hedef verin."
    }

    $workingDirectory = Split-Path -Parent $ExecutablePath
    $process = Start-Process -FilePath $ExecutablePath -WorkingDirectory $workingDirectory -PassThru
    $startedBySmoke = $true
  }

  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  do {
    $candidate = Get-VisibleAppProcess -Name $processName
    if ($candidate) {
      $process = $candidate
      break
    }
    Start-Sleep -Milliseconds 100
  } while ([DateTime]::UtcNow -lt $deadline)

  if (-not $process -or $process.MainWindowHandle -eq 0) {
    throw "Uygulama $TimeoutSeconds saniye icinde gorunur bir pencere vermedi."
  }

  if (-not $NoForeground) {
    [void][WindowsFastSmoke]::ShowWindow($process.MainWindowHandle, 9)
    [void][WindowsFastSmoke]::SetForegroundWindow($process.MainWindowHandle)
    Start-Sleep -Milliseconds 150
    $process.Refresh()
  }

  if ($DismissInitialDialog) {
    # Yalnız yerel/InMemory ilk açılışındaki "Yenilikler" penceresi için
    # isteğe bağlıdır. Varsayılan kapalıdır; kullanıcı akışına körlemesine
    # müdahale etmez.
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    if ($PostInteractionDelayMs -gt 0) {
      Start-Sleep -Milliseconds $PostInteractionDelayMs
    }
  }

  $rect = New-Object WindowsFastSmoke+RECT
  if (-not [WindowsFastSmoke]::GetWindowRect($process.MainWindowHandle, [ref]$rect)) {
    throw 'Pencere boyutu okunamadi.'
  }
  $width = [Math]::Max(0, $rect.Right - $rect.Left)
  $height = [Math]::Max(0, $rect.Bottom - $rect.Top)
  if ($width -lt 2 -or $height -lt 2) {
    throw "Gecersiz pencere boyutu: ${width}x${height}."
  }

  $outputDirectory = Split-Path -Parent $OutputPath
  New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
  $bitmap = New-Object System.Drawing.Bitmap $width, $height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    # Masaüstünü değil yalnız uygulama penceresinin kendi render çıktısını alır.
    # Böylece arkadaki kamera, sohbet veya başka bir uygulama kanıt dosyasına
    # sızamaz; PrintWindow başarısızsa smoke da başarısız sayılır.
    $deviceContext = $graphics.GetHdc()
    try {
      $printed = [WindowsFastSmoke]::PrintWindow($process.MainWindowHandle, $deviceContext, 2)
    }
    finally {
      $graphics.ReleaseHdc($deviceContext)
    }
    if (-not $printed) {
      throw 'Uygulama penceresi güvenli olarak yakalanamadı (PrintWindow başarısız).'
    }
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }

  $elapsedMs = [Math]::Round($stopwatch.Elapsed.TotalMilliseconds)
  $result = [ordered]@{
    passed = $true
    checkedAtUtc = [DateTime]::UtcNow.ToString('o')
    launchMode = if ($startedBySmoke) { 'launched_release' } else { 'attached_to_running_app' }
    processId = $process.Id
    windowTitle = $process.MainWindowTitle
    visibleWindowWithinMs = $elapsedMs
    timeoutSeconds = $TimeoutSeconds
    dismissInitialDialogRequested = [bool]$DismissInitialDialog
    screenshot = $OutputPath
    window = "${width}x${height}"
  }
  $result | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8

  Write-Output 'WINDOWS_FAST_SMOKE PASS'
  Write-Output ("mode={0}; pid={1}; visible_ms={2}; window={3}" -f $result.launchMode, $result.processId, $result.visibleWindowWithinMs, $result.window)
  Write-Output ("screenshot={0}" -f $OutputPath)
  Write-Output ("manifest={0}" -f $manifestPath)
}
catch {
  Write-Error ("WINDOWS_FAST_SMOKE FAIL: {0}" -f $_.Exception.Message)
  exit 1
}
finally {
  if ($CloseAfter -and $startedBySmoke -and $process) {
    try {
      if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
      }
    }
    catch {
      Write-Warning ("Smoke'un actigi surec kapatilamadi: {0}" -f $_.Exception.Message)
    }
  }
}
