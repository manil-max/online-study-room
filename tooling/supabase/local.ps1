[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('start', 'reset', 'test', 'baseline', 'status', 'stop')]
  [string]$Action = 'baseline',

  [string]$NodePath
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$cliEntry = Join-Path $repoRoot 'node_modules\supabase\dist\supabase.js'
$dockerCli = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$dockerDesktop = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
$dockerBin = Split-Path -Parent $dockerCli

# Docker Desktop may have been installed after the current terminal started.
# Make the CLI discoverable for child processes without changing machine state.
$processPath = [Environment]::GetEnvironmentVariable('Path', 'Process')
if (($processPath -split ';') -notcontains $dockerBin) {
  [Environment]::SetEnvironmentVariable('Path', "$dockerBin;$processPath", 'Process')
}

if (-not (Test-Path -LiteralPath $cliEntry)) {
  throw 'Pinned Supabase CLI is missing. Run pnpm install at the repository root.'
}

if ([string]::IsNullOrWhiteSpace($NodePath)) {
  $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
  if ($nodeCommand) {
    $NodePath = $nodeCommand.Source
  } else {
    $bundledNode = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
    if (Test-Path -LiteralPath $bundledNode) {
      $NodePath = $bundledNode
    }
  }
}

if ([string]::IsNullOrWhiteSpace($NodePath) -or -not (Test-Path -LiteralPath $NodePath)) {
  throw 'Node.js was not found. Install Node.js or pass -NodePath with an absolute node.exe path.'
}

function Invoke-LocalSupabase {
  param([Parameter(Mandatory)][string[]]$Arguments)
  & $NodePath $cliEntry @Arguments --workdir $repoRoot
  if ($LASTEXITCODE -ne 0) {
    throw "Supabase CLI failed: $($Arguments -join ' ')"
  }
}

function Wait-LocalDocker {
  if (-not (Test-Path -LiteralPath $dockerCli)) {
    throw 'Docker Desktop is not installed.'
  }

  & $dockerCli info --format '{{.ServerVersion}}' 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    if (-not (Test-Path -LiteralPath $dockerDesktop)) {
      throw 'Docker Desktop executable is missing.'
    }
    Start-Process -FilePath $dockerDesktop -WindowStyle Hidden
    foreach ($attempt in 1..36) {
      Start-Sleep -Seconds 5
      & $dockerCli info --format '{{.ServerVersion}}' 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) {
        return
      }
    }
    throw 'Docker engine did not become ready within 180 seconds.'
  }
}

Push-Location $repoRoot
try {
  switch ($Action) {
    'start' {
      Wait-LocalDocker
      Invoke-LocalSupabase @('start')
    }
    'reset' {
      Wait-LocalDocker
      Invoke-LocalSupabase @('start')
      Invoke-LocalSupabase @('db', 'reset')
    }
    'test' {
      Wait-LocalDocker
      Invoke-LocalSupabase @('test', 'db')
    }
    'baseline' {
      Wait-LocalDocker
      Invoke-LocalSupabase @('start')
      Invoke-LocalSupabase @('db', 'reset')
      Invoke-LocalSupabase @('test', 'db')
    }
    'status' {
      Invoke-LocalSupabase @('status')
    }
    'stop' {
      Invoke-LocalSupabase @('stop')
    }
  }
} finally {
  Pop-Location
}
