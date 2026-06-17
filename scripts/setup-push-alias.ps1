<#
.SYNOPSIS
  One-time setup for the `git ship` alias that runs the push and
  then watches the CI run.

.DESCRIPTION
  After this script runs, `git ship` (and `git ship origin main`,
  etc.) does a `git push` and, on success, blocks the terminal
  until the resulting CI run finishes. Exits 0 on CI success,
  non-zero on CI failure.

  Why `git ship` and not `git push`? On Windows + Git for Windows
  2.49, `git push` aliases are silently bypassed — `git` runs
  the built-in push command even when `alias.push` is set, both
  for `!`-style shell aliases and for plain command aliases
  (verified with `alias.push=status`, which had no effect). This
  appears to be a Git for Windows-specific quirk for the `push`
  builtin. Aliases for any other command (`git c`, `git hist`,
  `git ship`, etc.) work fine.

  This script is idempotent — running it twice is harmless.

.EXAMPLE
  pwsh scripts/setup-push-alias.ps1
#>

$ErrorActionPreference = 'Stop'

# Use the same PowerShell the user has on PATH, to match the
# alias exactly (i.e. `!powershell ...`).
$psCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
$aliasValue = "!$psCmd scripts/push-and-watch.ps1 --"

# Idempotency: only set if different.
$existing = git config --get alias.ship 2>$null
if ($existing -eq $aliasValue) {
    Write-Host "alias.ship already set to that value; nothing to do." -ForegroundColor DarkYellow
    exit 0
}

git config alias.ship $aliasValue
Write-Host "Set alias.ship = $aliasValue" -ForegroundColor Green
Write-Host ""
Write-Host "Try it:" -ForegroundColor Cyan
Write-Host "  git ship origin main" -ForegroundColor Cyan
Write-Host "    (pushes and watches CI; same as `git push origin main` but blocks"
Write-Host "     the terminal until CI finishes and prints PASS/FAIL.)" -ForegroundColor Cyan
