Get-Process | Where-Object {
  $_.ProcessName -match 'online|flutter|study_room' -or
  ($_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -ne '')
} | Select-Object Id, ProcessName, MainWindowTitle, MainWindowHandle |
  Sort-Object ProcessName |
  Format-Table -AutoSize | Out-String -Width 200 | Write-Output
