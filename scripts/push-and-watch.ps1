<#
.SYNOPSIS
  Run `git push` and, on success, watch the CI run it triggered.

.DESCRIPTION
  This script is meant to be invoked as a `git push` alias:

      git config alias.push '!powershell scripts/push-and-watch.ps1 --'

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

  Timeout for the CI watch can be overridden via the
  RFBROWSER_PUSH_WATCH_TIMEOUT environment variable (in minutes,
  default 15). No command-line parameter is exposed because
  PowerShell's `param()` block binds positionals to typed
  parameters, which conflicts with the way the git alias template
  splats `git push` args through to us.

.EXAMPLE
  # Set up once per clone:
  git config alias.push '!powershell scripts/push-and-watch.ps1 --'

  # Then just push as usual:
  git push origin main
#>

# No `param()` block on purpose. With `param([int]$TimeoutMinutes=15)`,
# PowerShell tried to bind the first positional arg (e.g. `--dry-run`)
# to $TimeoutMinutes and rejected it as a non-int. `ValueFromRemainingArguments`
# on a second param did not help either. The simplest fix is to
# declare no params at all, take everything from `$args`, and let
# the user override the timeout via the RFBROWSER_PUSH_WATCH_TIMEOUT
# environment variable.

$ErrorActionPreference = 'Stop'

# --- parse timeout + push args from $args -----------------------------------

$timeout = if ($env:RFBROWSER_PUSH_WATCH_TIMEOUT -match '^\d+$') {
    [int]$env:RFBROWSER_PUSH_WATCH_TIMEOUT
} else { 15 }

# The alias template puts a literal `--` as $args[0] before the
# user's `git push` flags. Strip it so `git push` doesn't choke on
# an unknown flag.
$pushArgs = $args
if ($pushArgs.Count -gt 0 -and $pushArgs[0] -eq '--') {
    $pushArgs = $pushArgs | Select-Object -Skip 1
}

# --- run the actual push ----------------------------------------------------

Write-Host "push-and-watch: running 'git push $($pushArgs -join ' ')'" -ForegroundColor Cyan
& git push @pushArgs
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
$psCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
& $psCmd -NoProfile -File $script -TimeoutMinutes $timeout
exit $LASTEXITCODE
