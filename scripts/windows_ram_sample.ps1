$exe = Resolve-Path (Join-Path $PSScriptRoot '..\app\build\windows\x64\runner\Release\online_study_room.exe')
$p = Start-Process -FilePath $exe.Path -PassThru
$samples = @()
for ($i = 0; $i -lt 20; $i++) {
  Start-Sleep -Seconds 2
  try {
    $p.Refresh()
    if ($p.HasExited) { break }
    $samples += [Math]::Round($p.WorkingSet64 / 1MB, 1)
  } catch { break }
}
$last = if ($samples.Count -gt 0) { $samples[-1] } else { 0 }
$avg = if ($samples.Count -gt 0) { [Math]::Round(($samples | Measure-Object -Average).Average, 1) } else { 0 }
Write-Output ("samples={0} lastWS_MB={1} avgWS_MB={2} series={3}" -f $samples.Count, $last, $avg, ($samples -join ','))
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
