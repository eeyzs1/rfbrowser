<#
.SYNOPSIS
  Watch the CI run triggered by `git push` and report pass/fail.

.DESCRIPTION
  This watcher is invoked by scripts/push-and-watch.ps1 (the
  `git ship` alias) after a successful push, and can also be
  called directly.

  Git has no native post-push hook, and on Windows + Git for
  Windows 2.49 `git push` aliases are silently bypassed, so
  `git ship` is the only way to chain arbitrary post-push work
  on the client side. This script is the actual watcher; the
  wrapper just makes sure it runs after the push.

  After it's invoked, this script:
    1. Resolves the repo owner/name and the current branch from
       local git config.
    2. Polls `gh run list` until a CI run for the current HEAD
       SHA appears (the runner takes a few seconds to register
       it, and `concurrency: cancel-in-progress: true` in the
       workflow means the run we want is the one whose headSha
       matches HEAD, not just the most recent one).
    3. Polls `gh run view` until the run completes, or a hard
       $TimeoutMinutes ceiling is hit.
    4. Prints a colored PASS/FAIL summary and the run URL.
       Exits non-zero on failure so a wrapper can chain.

.SETUP
  This repo ships a wrapper at scripts/push-and-watch.ps1 plus
  a one-time setup script:

      pwsh scripts/setup-push-alias.ps1

  That sets `alias.ship` so `git ship` (or `git ship origin
  main`, etc.) drives the push and then this watcher.

  Or call this script directly:

      pwsh scripts/post-push-check-ci.ps1

  Or against a specific run id (e.g. to re-check an old one):

      pwsh scripts/post-push-check-ci.ps1 -RunId 27660965043

.PARAMETER RunId
  Skip the "find the run for HEAD" poll and watch a specific
  run id. Useful when the script is run manually, minutes
  after a push.

.PARAMETER TimeoutMinutes
  Hard ceiling on total wall time. Default 15.
#>
param(
    [string]$RunId = "",
    [int]$TimeoutMinutes = 15
)

$ErrorActionPreference = 'Stop'

# --- preflight --------------------------------------------------------------

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "post-push: 'gh' CLI not on PATH; skipping CI watch." -ForegroundColor DarkYellow
    Write-Host "  Install: https://cli.github.com/" -ForegroundColor DarkYellow
    exit 0
}

$remoteUrl = (git remote get-url origin) -replace '\.git$', ''

# git remote get-url can return any of:
#   git@github.com:owner/repo
#   https://github.com/owner/repo
#   ssh://git@github.com/owner/repo
# Normalize to "owner/repo" for `gh --repo`.
if ($remoteUrl -match 'github\.com[:/]([^/]+/[^/]+)') {
    $repo = $Matches[1]
} else {
    Write-Host "post-push: origin is not a GitHub repo ($remoteUrl); skipping CI watch." -ForegroundColor DarkYellow
    exit 0
}

$headSha = (git rev-parse HEAD)
$branch  = (git rev-parse --abbrev-ref HEAD)
$shortSha = $headSha.Substring(0, [Math]::Min(7, $headSha.Length))
Write-Host "post-push: watching CI for $repo @ $branch ($shortSha)" -ForegroundColor Cyan

# --- find the run -----------------------------------------------------------

if (-not $RunId) {
    $found = $null
    $waitStart = Get-Date
    while (((Get-Date) - $waitStart).TotalSeconds -lt 60) {
        $list = gh run list --repo $repo --branch $branch --limit 10 --json databaseId,status,conclusion,headSha 2>$null
        if ($LASTEXITCODE -eq 0) {
            $data = $list | ConvertFrom-Json
            foreach ($run in $data) {
                if ($run.headSha -eq $headSha) {
                    $found = $run
                    break
                }
            }
            if ($found) { break }
        }
        Start-Sleep -Seconds 3
    }

    if (-not $found) {
        Write-Host "  no CI run registered for HEAD within 60s." -ForegroundColor DarkYellow
        Write-Host "  Watch all runs: https://github.com/$repo/actions" -ForegroundColor DarkYellow
        exit 0
    }

    $RunId      = $found.databaseId
    $status     = $found.status
    $conclusion = $found.conclusion
} else {
    $view = gh run view $RunId --repo $repo --json status,conclusion 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  run $RunId not found in $repo." -ForegroundColor Red
        exit 1
    }
    $data       = $view | ConvertFrom-Json
    $status     = $data.status
    $conclusion = $data.conclusion
}

Write-Host "  run id: $RunId" -ForegroundColor Cyan
Write-Host "  URL:    https://github.com/$repo/actions/runs/$RunId" -ForegroundColor Cyan

# --- poll until done --------------------------------------------------------

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
while ($status -ne "completed") {
    if ((Get-Date) -gt $deadline) {
        Write-Host ""
        Write-Host "  CI did not finish within $TimeoutMinutes minutes. Stopping poll;" -ForegroundColor DarkYellow
        Write-Host "  the run will keep going in the background:" -ForegroundColor DarkYellow
        Write-Host "  https://github.com/$repo/actions/runs/$RunId" -ForegroundColor DarkYellow
        exit 0
    }
    Start-Sleep -Seconds 10
    $view = gh run view $RunId --repo $repo --json status,conclusion 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  gh run view failed mid-poll; aborting." -ForegroundColor Red
        exit 1
    }
    $data       = $view | ConvertFrom-Json
    $status     = $data.status
    $conclusion = $data.conclusion
}

# --- report -----------------------------------------------------------------

Write-Host ""
Write-Host "  === CI Run $RunId ===" -ForegroundColor Cyan
$color = if ($conclusion -eq "success") { "Green" } else { "Red" }
Write-Host "  conclusion: $conclusion" -ForegroundColor $color
Write-Host "  URL:        https://github.com/$repo/actions/runs/$RunId" -ForegroundColor Cyan

if ($conclusion -ne "success") {
    Write-Host ""
    Write-Host "  CI did NOT pass. Open the URL above for the failing job." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  All green. Safe to merge / open PR." -ForegroundColor Green
exit 0
