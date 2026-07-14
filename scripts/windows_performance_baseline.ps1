[CmdletBinding()]
param(
    [string]$ExecutablePath,
    [string]$OutputDirectory,
    [ValidateRange(1, 20)]
    [int]$Runs = 5,
    [ValidateRange(10, 300)]
    [int]$IdleSeconds = 60,
    [ValidateRange(1, 10)]
    [int]$SampleIntervalSeconds = 1,
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($ExecutablePath)) {
    $ExecutablePath = Join-Path $scriptRoot '..\app\build\windows\x64\runner\Release\online_study_room.exe'
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $scriptRoot '..\app\build\windows-performance-baseline'
}

function Get-Percentile {
    param(
        [double[]]$Values,
        [ValidateRange(0, 1)]
        [double]$Percentile
    )

    if ($Values.Count -eq 0) {
        return $null
    }

    $sorted = $Values | Sort-Object
    $index = [Math]::Ceiling(($sorted.Count - 1) * $Percentile)
    return [Math]::Round([double]$sorted[$index], 2)
}

function Get-ProcessSample {
    param([System.Diagnostics.Process]$Process)

    $Process.Refresh()
    return [ordered]@{
        timestamp_utc = [DateTime]::UtcNow.ToString('o')
        working_set_bytes = [int64]$Process.WorkingSet64
        private_bytes = [int64]$Process.PrivateMemorySize64
        cpu_seconds = [Math]::Round($Process.TotalProcessorTime.TotalSeconds, 3)
    }
}

$resolvedExecutable = Resolve-Path -LiteralPath $ExecutablePath -ErrorAction Stop
$processName = [IO.Path]::GetFileNameWithoutExtension($resolvedExecutable.Path)
$artifactHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedExecutable.Path).Hash.ToLowerInvariant()
$validation = [ordered]@{
    schema_version = 1
    executable_name = [IO.Path]::GetFileName($resolvedExecutable.Path)
    executable_sha256 = $artifactHash
    runs = $Runs
    idle_seconds = $IdleSeconds
    sample_interval_seconds = $SampleIntervalSeconds
    output_directory = 'local build/windows-performance-baseline'
}

if ($ValidateOnly) {
    $validation | ConvertTo-Json -Depth 4
    exit 0
}

$alreadyRunning = Get-Process -Name $processName -ErrorAction SilentlyContinue
if ($alreadyRunning) {
    throw "Ölçümden önce açık $processName süreçlerini kapatın; mevcut süreçler değiştirilmeyecek."
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$runResults = @()

for ($run = 1; $run -le $Runs; $run++) {
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $resolvedExecutable.Path -PassThru
    $windowVisible = $false

    try {
        while ($stopwatch.Elapsed.TotalSeconds -lt 30) {
            Start-Sleep -Milliseconds 100
            $process.Refresh()
            if ($process.HasExited) {
                throw "Uygulama pencere oluşmadan kapandı (exit code: $($process.ExitCode))."
            }
            if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
                $windowVisible = $true
                break
            }
        }

        if (-not $windowVisible) {
            throw 'Pencere 30 saniye içinde görünmedi.'
        }

        $windowVisibleMilliseconds = [Math]::Round($stopwatch.Elapsed.TotalMilliseconds, 0)
        $samples = @()
        $sampleCount = [Math]::Floor($IdleSeconds / $SampleIntervalSeconds)
        for ($sample = 0; $sample -le $sampleCount; $sample++) {
            if ($process.HasExited) {
                throw "Uygulama boşta örnekleme sırasında kapandı (exit code: $($process.ExitCode))."
            }
            $samples += Get-ProcessSample -Process $process
            if ($sample -lt $sampleCount) {
                Start-Sleep -Seconds $SampleIntervalSeconds
            }
        }

        $runResults += [ordered]@{
            run = $run
            window_visible_milliseconds = $windowVisibleMilliseconds
            idle_cpu_seconds = [Math]::Round(
                $samples[-1].cpu_seconds - $samples[0].cpu_seconds,
                3
            )
            samples = $samples
        }
    }
    finally {
        if (-not $process.HasExited) {
            $null = $process.CloseMainWindow()
            if (-not $process.WaitForExit(10000)) {
                Stop-Process -Id $process.Id -Force
                $process.WaitForExit()
            }
        }
        $process.Dispose()
    }
}

$allSamples = @($runResults | ForEach-Object { $_.samples })
$workingSetMegabytes = @($allSamples | ForEach-Object { [Math]::Round($_.working_set_bytes / 1MB, 2) })
$privateMegabytes = @($allSamples | ForEach-Object { [Math]::Round($_.private_bytes / 1MB, 2) })
$idleCpuSeconds = @($runResults | ForEach-Object { [double]$_.idle_cpu_seconds })
$windowMilliseconds = @($runResults | ForEach-Object { [double]$_.window_visible_milliseconds })

$result = [ordered]@{
    schema_version = 1
    captured_at_utc = [DateTime]::UtcNow.ToString('o')
    app = [ordered]@{
        executable_name = [IO.Path]::GetFileName($resolvedExecutable.Path)
        executable_sha256 = $artifactHash
    }
    environment = [ordered]@{
        os_caption = (Get-CimInstance Win32_OperatingSystem).Caption
        os_version = [Environment]::OSVersion.Version.ToString()
        process_architecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
    }
    configuration = [ordered]@{
        runs = $Runs
        idle_seconds = $IdleSeconds
        sample_interval_seconds = $SampleIntervalSeconds
    }
    summary = [ordered]@{
        window_visible_milliseconds = [ordered]@{
            p50 = Get-Percentile -Values $windowMilliseconds -Percentile 0.5
            p95 = Get-Percentile -Values $windowMilliseconds -Percentile 0.95
        }
        working_set_megabytes = [ordered]@{
            p50 = Get-Percentile -Values $workingSetMegabytes -Percentile 0.5
            p95 = Get-Percentile -Values $workingSetMegabytes -Percentile 0.95
        }
        private_megabytes = [ordered]@{
            p50 = Get-Percentile -Values $privateMegabytes -Percentile 0.5
            p95 = Get-Percentile -Values $privateMegabytes -Percentile 0.95
        }
        idle_cpu_seconds = [ordered]@{
            p50 = Get-Percentile -Values $idleCpuSeconds -Percentile 0.5
            p95 = Get-Percentile -Values $idleCpuSeconds -Percentile 0.95
        }
    }
    runs = $runResults
}

$resultPath = Join-Path $OutputDirectory ("baseline-{0:yyyyMMdd-HHmmss}.json" -f [DateTime]::UtcNow)
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding utf8
Write-Output "Baseline written: $resultPath"
