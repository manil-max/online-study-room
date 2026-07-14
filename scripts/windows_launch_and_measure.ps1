$ErrorActionPreference = 'Stop'
$exe = Resolve-Path (Join-Path $PSScriptRoot '..\app\build\windows\x64\runner\Release\online_study_room.exe')

Get-Process online_study_room -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$p = Start-Process -FilePath $exe.Path -PassThru -WorkingDirectory (Split-Path $exe.Path)
Write-Output ("STARTED pid={0}" -f $p.Id)

# Wait for window + login/data settle
$samples = @()
for ($i = 0; $i -lt 25; $i++) {
  Start-Sleep -Seconds 2
  try {
    $p.Refresh()
    if ($p.HasExited) { Write-Output 'PROCESS_EXITED'; break }
    $mb = [Math]::Round($p.WorkingSet64 / 1MB, 1)
    $priv = [Math]::Round($p.PrivateMemorySize64 / 1MB, 1)
    $samples += $mb
    if ($i -eq 0 -or $i % 5 -eq 0 -or $i -eq 24) {
      Write-Output ("t={0}s WS={1}MB Private={2}MB title={3}" -f (($i+1)*2), $mb, $priv, $p.MainWindowTitle)
    }
  } catch { break }
}

if ($samples.Count -gt 0) {
  $avg = [Math]::Round(($samples | Measure-Object -Average).Average, 1)
  $last = $samples[-1]
  $min = ($samples | Measure-Object -Minimum).Minimum
  $max = ($samples | Measure-Object -Maximum).Maximum
  Write-Output ("SUMMARY avg={0} last={1} min={2} max={3} samples={4}" -f $avg, $last, $min, $max, $samples.Count)
}

# Bring to front
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinFront {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
try {
  $p.Refresh()
  if ($p.MainWindowHandle -ne [IntPtr]::Zero) {
    [void][WinFront]::ShowWindow($p.MainWindowHandle, 9)
    [void][WinFront]::SetForegroundWindow($p.MainWindowHandle)
    Write-Output 'FOREGROUND_OK'
  } else {
    Write-Output 'NO_MAIN_WINDOW_YET'
  }
} catch {
  Write-Output ("FOREGROUND_FAIL {0}" -f $_.Exception.Message)
}

# Screenshot
try {
  Add-Type -AssemblyName System.Drawing
  Add-Type -AssemblyName System.Windows.Forms
  $p.Refresh()
  $hwnd = $p.MainWindowHandle
  if ($hwnd -ne [IntPtr]::Zero) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinRect {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
    $rect = New-Object WinRect+RECT
    [void][WinRect]::GetWindowRect($hwnd, [ref]$rect)
    $w = [Math]::Max(1, $rect.Right - $rect.Left)
    $h = [Math]::Max(1, $rect.Bottom - $rect.Top)
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size $w, $h))
    $out = Join-Path $PSScriptRoot '..\app\build\windows_release_smoke.png'
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Output ("SCREENSHOT {0}" -f (Resolve-Path $out))
  }
} catch {
  Write-Output ("SCREENSHOT_FAIL {0}" -f $_.Exception.Message)
}

Write-Output 'APP_LEFT_RUNNING'
