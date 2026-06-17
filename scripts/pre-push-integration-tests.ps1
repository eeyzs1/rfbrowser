<#
.SYNOPSIS
  Run the RFBrowser integration tests that need a real Win32 desktop.

.DESCRIPTION
  integration_test/ contains real Flutter integration tests. They
  compile rfbrowser.exe with the test file as main(), launch it, and
  attach a Dart VM debugger. The Flutter engine must create a hidden
  HWND during init, which only works on a real interactive desktop.
  The github-hosted CI runner cannot provide that environment, so
  these tests are NOT in CI; run this script locally before each
  push to confirm they still pass on your real Windows desktop.

  Wire it into a git pre-push hook to make the push fail
  automatically when the tests fail:

      # .git/hooks/pre-push
      pwsh scripts/pre-push-integration-tests.ps1
      exit $LASTEXITCODE

.PARAMETER TestFile
  Run only the specified test file (e.g.
  integration_test/plugin_settings_test.dart). If omitted, runs the
  same set the CI used to run under the (now-removed)
  integration-test-windows job.

.EXAMPLE
  pwsh scripts/pre-push-integration-tests.ps1

.EXAMPLE
  pwsh scripts/pre-push-integration-tests.ps1 -TestFile integration_test/plugin_settings_test.dart
#>
param(
    [string]$TestFile = ""
)

$ErrorActionPreference = 'Stop'

# Tests that used to run under the (now-removed) integration-test-windows
# job. Add new ones here when they need to be part of the pre-push gate.
$defaultTests = @(
    "integration_test/plugin_lifecycle_test.dart"
    "integration_test/plugin_settings_test.dart"
)

$tests = if ($TestFile) { @($TestFile) } else { $defaultTests }

Write-Host "=== RFBrowser Pre-Push Integration Tests ===" -ForegroundColor Cyan
Write-Host "These tests need a real Win32 desktop and are not run in CI." -ForegroundColor Cyan
Write-Host ""

# Refresh the project's generated code so the test binary builds
# against the same packages / l10n the rest of the workspace sees.
Write-Host "[setup] flutter pub get"
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter pub get FAILED" -ForegroundColor Red
    exit 1
}

Write-Host "[setup] flutter gen-l10n"
flutter gen-l10n
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter gen-l10n FAILED" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Each test gets a 5-minute hard cap. flutter test for an integration
# test normally takes 2-3 minutes on a real desktop; if it runs
# longer the test binary is stuck (no real desktop, missing DLL,
# WebView2 not installed, etc.) and waiting longer just wastes time.
$timeoutSec = 5 * 60

$failed = @()
foreach ($test in $tests) {
    Write-Host "[run] $test" -ForegroundColor Cyan

    $p = Start-Process -FilePath "flutter" `
        -ArgumentList @("test", $test, "--no-pub") `
        -NoNewWindow -PassThru `
        -WorkingDirectory (Get-Location).Path

    if ($p.WaitForExit($timeoutSec * 1000)) {
        if ($p.ExitCode -ne 0) {
            Write-Host "  FAILED (exit code $($p.ExitCode))" -ForegroundColor Red
            $failed += $test
        } else {
            Write-Host "  PASSED" -ForegroundColor Green
        }
    } else {
        Write-Host "  TIMEOUT after $timeoutSec seconds — killing flutter test." -ForegroundColor Red
        try {
            $p.Kill($true)
        } catch {
            Write-Host "  (kill failed: $($_.Exception.Message))" -ForegroundColor DarkYellow
        }
        $failed += $test
    }
    Write-Host ""
}

Write-Host "=== Summary ===" -ForegroundColor Cyan
foreach ($test in $tests) {
    $status = if ($failed -contains $test) { "FAIL" } else { "PASS" }
    $color = if ($failed -contains $test) { "Red" } else { "Green" }
    Write-Host ("  [{0}] {1}" -f $status, $test) -ForegroundColor $color
}

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "Some tests failed. Do NOT push until they pass." -ForegroundColor Red
    Write-Host "Failed: $($failed -join ', ')"
    exit 1
}

Write-Host ""
Write-Host "All integration tests passed. Safe to push." -ForegroundColor Green
exit 0
