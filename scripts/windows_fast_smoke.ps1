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

    # 🔴 WP-602: "PrintWindow başarısızsa smoke da başarısız sayılır" cümlesi
    # DOĞRU ama ETKİSİZ. Çağrı başarısız olmuyor: `True` dönüyor ve BOŞ BEYAZ
    # bir istemci alanı üretiyor. Ölçüldü (2026-08-09, bu makine, gerçek
    # Windows derlemesi): PrintWindow ve ekrandan `CopyFromScreen` — ikisi de
    # başlık çubuğunu (native Win32) yakalıyor, Flutter'ın çizdiği istemci
    # alanını yakalayamıyor; 25 saniye beklendiğinde de aynı. Sebep, Flutter'ın
    # Windows'ta DirectComposition/ANGLE yüzeyine çizmesi — GDI'nın kör noktası.
    #
    # Bunun bedeli somut: manifest `screenshot` alanını KANIT diye kaydediyor,
    # QA belgesi de "görüntü doğrulandı" yazıyordu. Kapının gerçek sinyali
    # aşağıdaki PENCERE BAŞLIĞI kontrolü; ekran görüntüsü kanıt gibi sunulan
    # boş bir dosyaydı. Bu depoda tekrarlayan hata: kapı vardı, ölçtüğü şey
    # yoktu.
    #
    # Burada yapılan: yakalamayı DÜZELTMEK değil (GDI ile mümkün değil),
    # DÜRÜST OLMAK. Boş görüntü artık boş olduğunu söylüyor.
    # 🔴 Ölçüt "kaç farklı renk var" DEĞİL, "tek renk yüzeyin ne kadarını
    # kaplıyor". İlk deneme renk sayısıyla yazılmıştı ve GERÇEK boş çıktıda 8
    # renk saydığı için hatayı KAÇIRIYORDU: pencere kenarı/gölgesi örneklemeye
    # sızıyor. Ölçüldü (aynı makine, aynı dosyalar):
    #   gerçek boş yakalama  -> baskın oran 1.0000 (tek renk)
    #   dolu bir arayüz      -> baskın oran 0.5142
    # Ayrım temiz; eşik 0.98.
    $dominantFraction = 1.0
    $distinctColors = 1
    $probe = New-Object System.Drawing.Bitmap $OutputPath
    try {
      # Kenarlardan içeri gir: başlık çubuğu ve pencere çerçevesi native
      # olduğu için HER ZAMAN yakalanıyor; onları ölçmek boşluğu gizlerdi.
      $insetX = [int]($probe.Width * 0.08)
      $insetY = [int]($probe.Height * 0.12)
      $x0 = $insetX; $x1 = $probe.Width - $insetX
      $y0 = $insetY; $y1 = $probe.Height - $insetY
      if (($x1 - $x0) -gt 8 -and ($y1 - $y0) -gt 8) {
        $counts = @{}
        $samples = 0
        $stepX = [Math]::Max(1, [int](($x1 - $x0) / 100))
        $stepY = [Math]::Max(1, [int](($y1 - $y0) / 100))
        for ($px = $x0; $px -lt $x1; $px += $stepX) {
          for ($py = $y0; $py -lt $y1; $py += $stepY) {
            $argb = $probe.GetPixel($px, $py).ToArgb()
            $counts[$argb] = 1 + [int]$counts[$argb]
            $samples++
          }
        }
        if ($samples -gt 0) {
          $dominantFraction = [Math]::Round(
            (($counts.Values | Sort-Object -Descending | Select-Object -First 1) / $samples), 4)
          $distinctColors = $counts.Count
        }
      }
    }
    finally { $probe.Dispose() }
    # Amaç "ekran DOĞRU mu" demek değil — o insan işi. Amaç "bu dosya kanıt
    # sayılabilir mi" demek.
    $screenshotUsable = $dominantFraction -lt 0.98
    $screenshotNote = if ($screenshotUsable) { '' } else {
      "Yakalanan istemci alani tek duze (baskin renk orani $dominantFraction, $distinctColors farkli renk): GDI Flutter yuzeyini goremiyor. Bu PNG KANIT DEGILDIR; kapinin gecerli sinyali pencere basligi kontroludur."
    }
    if (-not $screenshotUsable) {
      Write-Warning $screenshotNote
    }
  }
  finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }

  # 🔴 WP-465 bulgusu: bu betik eskiden yalnız "görünür bir pencere oluştu mu"
  # ölçüyordu ve ölümcül yapılandırma hatası ekranındaki uygulamaya da PASS
  # diyordu (kanıt: docs/qa/V57-FULL-REGRESSION.md §5.3). Ekran görüntüsü
  # üretiliyordu ama kimse bakmazsa kapı yeşil raporluyordu.
  #
  # Ayırt edici sinyal, ürün tarafına hiç dokunmadan mevcut: pencere başlığı.
  #   * `windows/runner/main.cpp` pencereyi SABİT `Odak Kampi` (ASCII i) ile açar
  #   * Dart başlığı ancak `desktop_window_io.dart` içindeki `WindowOptions`
  #     ile, yani yapılandırma doğrulaması GEÇTİKTEN sonra yerelleştirilmiş
  #     ada çevirir: TR `Odak Kampı` (noktalı ı), EN `Focus Camp`.
  # Başlık hâlâ bootstrap değeriyse Dart o noktaya hiç ulaşmamıştır.
  $process.Refresh()
  $observedTitle = $process.MainWindowTitle
  $bootstrapTitle = 'Odak Kampi'
  if ($observedTitle -ceq $bootstrapTitle) {
    throw ("Uygulama acildi ama Dart masaustu kurulumuna hic ulasmadi: pencere " +
      "basligi hala native bootstrap degeri ('$bootstrapTitle'). En olasi sebep " +
      "yapilandirma hata ekrani (ornegin invalid_version_build). Ekran " +
      "goruntusu alindi (kanit sayilir mi: $screenshotUsable): $OutputPath")
  }
  if ([string]::IsNullOrWhiteSpace($observedTitle)) {
    throw "Pencere basligi bos; uygulama acilisi tamamlanmamis. Ekran goruntusu: $OutputPath"
  }

  $elapsedMs = [Math]::Round($stopwatch.Elapsed.TotalMilliseconds)
  $result = [ordered]@{
    passed = $true
    checkedAtUtc = [DateTime]::UtcNow.ToString('o')
    launchMode = if ($startedBySmoke) { 'launched_release' } else { 'attached_to_running_app' }
    processId = $process.Id
    windowTitle = $observedTitle
    visibleWindowWithinMs = $elapsedMs
    timeoutSeconds = $TimeoutSeconds
    dismissInitialDialogRequested = [bool]$DismissInitialDialog
    screenshot = $OutputPath
    # WP-602: dosyanın varlığı kanıt değildir; kullanılabilirliği ayrı alan.
    screenshotUsable = $screenshotUsable
    screenshotDominantColorFraction = $dominantFraction
    screenshotNote = $screenshotNote
    window = "${width}x${height}"
  }
  $result | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8

  Write-Output 'WINDOWS_FAST_SMOKE PASS'
  Write-Output ("mode={0}; pid={1}; visible_ms={2}; window={3}; title={4}" -f $result.launchMode, $result.processId, $result.visibleWindowWithinMs, $result.window, $result.windowTitle)
  Write-Output ("screenshot={0} (kanit_sayilir={1})" -f $OutputPath, $screenshotUsable)
  Write-Output ("manifest={0}" -f $manifestPath)

  # 🔴 WP-640: basari yolunda cikis kodu ACIK yazilir. Betik sessizce bitince
  # cagiran `-File` kullanmiyorsa `$LASTEXITCODE` hic yazilmiyor ve cagiran
  # tarafta `$null` kaliyordu; iki Windows yayini bu yuzden dustu. Cikis
  # kodu bu betigin sozlesmesidir, yan etkisi degil.
  exit 0
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
