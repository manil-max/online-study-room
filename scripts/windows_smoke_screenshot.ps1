Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinSmoke {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@

$p = Get-Process -Name 'online_study_room' -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowHandle -ne 0 } |
  Select-Object -First 1

if (-not $p) {
  Write-Output 'NO_WINDOW'
  exit 1
}

Write-Output ("FOUND id={0} title={1} hwnd={2}" -f $p.Id, $p.MainWindowTitle, $p.MainWindowHandle)

[void][WinSmoke]::ShowWindow($p.MainWindowHandle, 9)
[void][WinSmoke]::SetForegroundWindow($p.MainWindowHandle)
Start-Sleep -Milliseconds 1000

$rect = New-Object WinSmoke+RECT
[void][WinSmoke]::GetWindowRect($p.MainWindowHandle, [ref]$rect)
$w = [Math]::Max(1, $rect.Right - $rect.Left)
$h = [Math]::Max(1, $rect.Bottom - $rect.Top)
Write-Output ("RECT L={0} T={1} W={2} H={3}" -f $rect.Left, $rect.Top, $w, $h)

$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size $w, $h))
$path = 'C:\Users\muhlis2\OneDrive\Desktop\Dev\online-study-room\app\build\windows_shell_smoke.png'
$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Output ("SAVED $path")
