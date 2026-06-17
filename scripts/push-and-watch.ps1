<#
.SYNOPSIS
  Run `git push` and, on success, watch the CI run it triggered.

.DESCRIPTION
  This script is meant to be invoked as a `git push` alias:

      git config alias.push '!pwsh scripts/push-and-watch.ps1 --'

  With that alias in place, typing `git push` (or `git push origin
  main`, etc.) does the push and then blocks the terminal until
  the resulting CI run completes (or hits a hard timeout). On
  success, prints "All green."; on failure, prints the run URL and
  exits non-zero so a wrapper can chain.

  Why an alias and not a post-push hook? Windows + Git for Windows
  2.49 has no `post-push` hook in its hooks list. (Only `pre-push`
  exists on the client side; the server-side hooks are
  `pre-receive` / `update` / `post-receive`, none of which run on
  the pusher's machine.) A `git push` alias is the only way to
  chain arbitrary post-push work on the client side without
  changing the user's workflow.

.PARAMETER TimeoutMinutes
  Hard ceiling on the total wall time the CI watch will block.
  The push itself is not counted toward this. 0 means default 15.

.EXAMPLE
  # Set up once per clone:
  git config alias.push '!pwsh scripts/push-and-watch.ps1 --'

  # Then just push as usual:
  git push origin main
#>
param(
    [int]$TimeoutMinutes = 15
)

$ErrorActionPreference = 'Stop'

# --- run the actual push ----------------------------------------------------

# Anything after `--` (the alias template) lands in $args. Splat them
# straight through to `git push`.
Write-Host "push-and-watch: running 'git push $args'" -ForegroundColor Cyan
& git push @args
$pushExit = $LASTEXITCODE

if ($pushExit -ne 0) {
    Write-Host "push-and-watch: git push exited $pushExit; skipping CI watch." -ForegroundColor Red
    exit $pushExit
}

Write-Host "push-and-watch: push succeeded; watching CI..." -ForegroundColor Cyan

# --- delegate the watch to post-push-check-ci.ps1 --------------------------

$script = Join-Path (git rev-parse --show-toplevel) 'scripts\post-push-check-ci.ps1'
if (-not (Test-Path $script)) {
    Write-Host "push-and-watch: $script not found; cannot watch CI." -ForegroundColor DarkYellow
    exit 0
}

# Bump the timeout a bit because we already burned some time on the
# push itself.
& pwsh -NoProfile -File $script -TimeoutMinutes $TimeoutMinutes
exit $LASTEXITCODE
