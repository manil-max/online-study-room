[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('start', 'reset', 'test', 'baseline', 'status', 'stop')]
  [string]$Action = 'baseline',

  [string]$NodePath,
  [string]$EvidenceRoot
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DeployGuard.psm1') -Force

$repoRoot = Get-RepoRoot
$cliEntry = Join-Path $repoRoot 'node_modules\supabase\dist\supabase.js'
$isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$dockerCli = if ($isWindowsHost) { 'C:\Program Files\Docker\Docker\resources\bin\docker.exe' } else { (Get-Command docker -ErrorAction SilentlyContinue).Source }
$dockerDesktop = if ($isWindowsHost) { 'C:\Program Files\Docker\Docker\Docker Desktop.exe' } else { $null }
$dockerBin = if ([string]::IsNullOrWhiteSpace($dockerCli)) { $null } else { Split-Path -Parent $dockerCli }
$startedAt = (Get-Date).ToUniversalTime()
$evidenceDirectory = New-EvidenceDirectory -Kind "local-$Action" -EvidenceRoot $EvidenceRoot -RepoRoot $repoRoot
$steps = [Collections.Generic.List[string]]::new()
$status = 'failed'
$failure = $null

# Docker Desktop may have been installed after the current terminal started.
$processPath = [Environment]::GetEnvironmentVariable('Path', 'Process')
if ($isWindowsHost -and -not [string]::IsNullOrWhiteSpace($dockerBin) -and ($processPath -split ';') -notcontains $dockerBin) {
  [Environment]::SetEnvironmentVariable('Path', "$dockerBin;$processPath", 'Process')
}

function Invoke-LocalSupabase {
  param(
    [Parameter(Mandatory)][string[]]$Arguments,
    [Parameter(Mandatory)][string]$Label
  )

  Assert-SafeSupabaseArguments -Arguments $Arguments
  $steps.Add($Label)
  $nodeArguments = @($cliEntry) + $Arguments + @('--workdir', $repoRoot)
  Invoke-EvidenceCommand -Executable $NodePath -Arguments $nodeArguments -EvidenceDirectory $evidenceDirectory -Label $Label | Out-Null
}

function Wait-LocalDocker {
  if (-not (Test-Path -LiteralPath $dockerCli)) {
    throw 'Docker Desktop is not installed.'
  }

  & $dockerCli info --format '{{.ServerVersion}}' 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    if (-not $isWindowsHost) {
      throw 'Docker engine is not ready on this host.'
    }
    if (-not (Test-Path -LiteralPath $dockerDesktop)) {
      throw 'Docker Desktop executable is missing.'
    }
    Start-Process -FilePath $dockerDesktop -WindowStyle Hidden
    foreach ($attempt in 1..36) {
      Start-Sleep -Seconds 5
      & $dockerCli info --format '{{.ServerVersion}}' 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) { return }
    }
    throw 'Docker engine did not become ready within 180 seconds.'
  }
}

function Ensure-LocalSupabase {
  param([Parameter(Mandatory)][string]$Label)

  $previousPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    & $NodePath $cliEntry status --workdir $repoRoot *> $null
    $statusExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
  }

  if ($statusExitCode -eq 0) {
    $steps.Add($Label)
    $message = 'Supabase local stack is already running; start is an idempotent no-op.'
    [IO.File]::WriteAllText((Join-Path $evidenceDirectory "$Label.log"), $message + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    Write-Host $message
    return
  }

  # A cancelled reset can leave stopped/orphaned local containers while
  # `supabase status` reports failure. The local stack is disposable and the
  # caller is about to replay it, so clear only this workdir's local volumes.
  Invoke-LocalSupabase -Arguments @('stop', '--no-backup') -Label "$Label-recover-stop"
  Invoke-LocalSupabase -Arguments @('start') -Label $Label
}

function Write-LocalManifest {
  $contract = Get-DeployContract -RepoRoot $repoRoot
  $manifest = [ordered]@{
    schema_version = 1
    kind = 'local-supabase'
    environment = 'local'
    action = $Action
    status = $status
    git_sha = Get-GitHead -RepoRoot $repoRoot
    migration_head = Get-LocalMigrationHead -RepoRoot $repoRoot
    contract_migration_head = $contract.local_migration_head
    supabase_cli_version = '2.109.1'
    started_at_utc = $startedAt.ToString('o')
    completed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    steps = @($steps)
    failure = Protect-DeployText -Text $failure
  }
  Write-DeployJson -Value $manifest -Path (Join-Path $evidenceDirectory 'deploy-manifest.json')
  Write-Host "Evidence: $evidenceDirectory"
}

Push-Location $repoRoot
try {
  if (-not (Test-Path -LiteralPath $cliEntry)) {
    throw 'Pinned Supabase CLI is missing. Run pnpm install at the repository root.'
  }
  if ([string]::IsNullOrWhiteSpace($NodePath)) {
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCommand) {
      $NodePath = $nodeCommand.Source
    } else {
      $bundledNode = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
      if (Test-Path -LiteralPath $bundledNode) { $NodePath = $bundledNode }
    }
  }
  if ([string]::IsNullOrWhiteSpace($NodePath) -or -not (Test-Path -LiteralPath $NodePath)) {
    throw 'Node.js was not found. Install Node.js or pass -NodePath with an absolute node.exe path.'
  }

  $contract = Get-DeployContract -RepoRoot $repoRoot
  $localHead = Get-LocalMigrationHead -RepoRoot $repoRoot
  if ($localHead -ne $contract.local_migration_head) {
    throw "Deploy contract drift: local migration head is $localHead, contract says $($contract.local_migration_head)."
  }

  switch ($Action) {
    'start' {
      Wait-LocalDocker
      Ensure-LocalSupabase -Label '01-start'
    }
    'reset' {
      Wait-LocalDocker
      Ensure-LocalSupabase -Label '01-start'
      Invoke-LocalSupabase -Arguments @('db', 'reset') -Label '02-reset'
    }
    'test' {
      Wait-LocalDocker
      Invoke-LocalSupabase -Arguments @('test', 'db', '--local') -Label '01-test'
    }
    'baseline' {
      Wait-LocalDocker
      Ensure-LocalSupabase -Label '01-start'
      Invoke-LocalSupabase -Arguments @('db', 'reset') -Label '02-reset'
      Invoke-LocalSupabase -Arguments @('test', 'db', '--local') -Label '03-test'
    }
    'status' {
      Invoke-LocalSupabase -Arguments @('status') -Label '01-status'
    }
    'stop' {
      Invoke-LocalSupabase -Arguments @('stop') -Label '01-stop'
    }
  }
  $status = 'success'
} catch {
  $failure = $_.Exception.Message
  throw
} finally {
  Write-LocalManifest
  Pop-Location
}
